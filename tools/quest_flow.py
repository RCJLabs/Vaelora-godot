"""Writes docs/QUEST_FLOW.md: every quest as a flowchart, and every story flag with
where it's set and where it's checked. Read from the game's own data, so it can't
drift from the game; re-run it after changing a quest, a dialogue or a flag.

    python3 tools/quest_flow.py           write the doc
    python3 tools/quest_flow.py --check   exit 1 if the doc is out of date, or a flag is
                                          checked but nothing sets it (run_tests.py runs this)

Sources: godot/quests/quests.json, godot/dialogue/*.json, and flag names written
literally in scripts (set_flag("x"), has_flag("x")) and scenes (cleared_flag = "x",
show_flag = "x", ...). Flags built at runtime (e.g. "shrine_blessed_day_%d") show up
only where they're written literally.
"""
import glob
import json
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
GODOT = os.path.join(ROOT, "godot")
OUT = os.path.join(ROOT, "docs", "QUEST_FLOW.md")

# Flags whose names are built at runtime, so no file spells them out in full.
RUNTIME_FLAGS = {
    "hint_": "Hints.show_once(id) sets hint_<id> (systems/hints.gd)",
    "readings_": "props/reading_stone.gd sets readings_1..3",
    "taken:": "interactables/pickup.gd sets taken:<level>/<node> when picked up",
    "opening_": "systems/openings.gd sets opening_<background>",
    "shrine_blessed_day_": "props/shrine.gd sets one per day",
}


def as_list(value):
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def rel(path):
    return os.path.relpath(path, GODOT).replace(os.sep, "/")


def describe(condition):
    """A condition dict as short text: 'flag_a, not flag_b, has item x'."""
    parts = []
    for flag in as_list(condition.get("requires_flag")):
        parts.append(flag)
    for flag in as_list(condition.get("requires_not_flag")):
        parts.append("not " + flag)
    for item in as_list(condition.get("requires_item")):
        parts.append("has " + (item if isinstance(item, str) else "%s x%d" % (item["id"], item.get("count", 1))))
    for item in as_list(condition.get("requires_not_item")):
        parts.append("no " + item)
    for trait in as_list(condition.get("requires_trait")):
        parts.append("trait " + trait)
    for key, label in [("requires_background", "background"), ("requires_race", "race"),
                       ("requires_gold", "gold >="), ("requires_corruption", "corruption tier >="),
                       ("requires_corruption_below", "corruption tier <")]:
        if key in condition:
            parts.append("%s %s" % (label, condition[key]))
    for faction, value in condition.get("requires_reputation", {}).items():
        parts.append("%s reputation >= %s" % (faction, value))
    for faction, value in condition.get("requires_reputation_below", {}).items():
        parts.append("%s reputation < %s" % (faction, value))
    return ", ".join(parts) if parts else "always"


def mermaid_text(text):
    return text.replace('"', "'").replace("\n", " ")


class Index:
    def __init__(self):
        self.set_by = defaultdict(set)
        self.read_by = defaultdict(set)

    def conditions(self, condition, where):
        for key in ["requires_flag", "requires_not_flag"]:
            for flag in as_list(condition.get(key)):
                self.read_by[flag].add(where)


def scan_dialogue(index):
    for path in sorted(glob.glob(os.path.join(GODOT, "dialogue", "*.json"))):
        name = os.path.basename(path)[:-5]
        data = json.load(open(path, encoding="utf-8"))
        for entry in as_list(data.get("start", [])):
            if isinstance(entry, str):
                continue   # a plain starting node, no conditions
            index.conditions(entry, "%s (start → %s)" % (name, entry.get("node", "?")))
        for node_id, node in data.get("nodes", {}).items():
            where = "%s: %s" % (name, node_id)
            for flag in as_list(node.get("set_flag")):
                index.set_by[flag].add(where)
            index.conditions(node, where)
            for choice in node.get("choices", []):
                said = choice.get("text", "")
                said = said if len(said) <= 40 else said[:37] + "..."
                choice_where = '%s: %s, "%s"' % (name, node_id, said)
                for flag in as_list(choice.get("set_flag")):
                    index.set_by[flag].add(choice_where)
                index.conditions(choice, choice_where)


def scan_quests(index, quests):
    for quest_id, quest in quests.items():
        where = "quest " + quest_id
        index.conditions(quest.get("started_when", {}), where)
        index.conditions(quest.get("completed_when", {}), where)
        for objective in quest.get("objectives", []):
            index.conditions(objective.get("done_when", {}), where)
        for outcome in quest.get("outcomes", []):
            index.conditions(outcome.get("when", {}), where)


def script_sets(script_path, prop, cache={}):
    """Whether this script passes its `prop` property to set_flag (else it only reads it)."""
    if script_path not in cache:
        cache[script_path] = open(script_path, encoding="utf-8").read() if os.path.exists(script_path) else ""
    return re.search(r"set_flag\(\s*%s\s*\)" % re.escape(prop), cache[script_path]) is not None


def res_path(path):
    return os.path.join(GODOT, path.replace("res://", ""))


def scene_root_script(scene_path):
    """The script on a scene's root node (for instanced scenes), or None."""
    if not os.path.exists(scene_path):
        return None
    resources, in_root = {}, False
    for line in open(scene_path, encoding="utf-8"):
        m = re.match(r'\[ext_resource .*path="([^"]+)".*id="([^"]+)"', line)
        if m:
            resources[m.group(2)] = m.group(1)
        if line.startswith("[node "):
            if in_root:
                break
            in_root = "parent=" not in line
        m = re.match(r'script = ExtResource\("([^"]+)"\)', line)
        if in_root and m:
            return res_path(resources[m.group(1)])
    return None


def scan_code(index):
    call = re.compile(r'\b(set_flag|has_flag)\("([a-z0-9_:]+)"\)')
    prop = re.compile(r'\b([a-z_]*flag[a-z_]*)\s*(?::\s*String)?\s*=\s*"([a-z0-9_]+)"')
    for path in sorted(glob.glob(os.path.join(GODOT, "**", "*.gd"), recursive=True)):
        if "/tests/" in path.replace(os.sep, "/") or "/addons/" in path.replace(os.sep, "/"):
            continue
        for number, line in enumerate(open(path, encoding="utf-8"), 1):
            where = "%s:%d" % (rel(path), number)
            for kind, flag in call.findall(line):
                (index.set_by if kind == "set_flag" else index.read_by)[flag].add(where)
            if "@export" in line:
                for name, flag in prop.findall(line):
                    (index.set_by if script_sets(path, name) else index.read_by)[flag].add(where)
    for path in sorted(glob.glob(os.path.join(GODOT, "**", "*.tscn"), recursive=True)):
        if "/tests/" in path.replace(os.sep, "/") or "/addons/" in path.replace(os.sep, "/"):
            continue
        resources, node, script = {}, "", None
        for line in open(path, encoding="utf-8"):
            m = re.match(r'\[ext_resource .*path="([^"]+)".*id="([^"]+)"', line)
            if m:
                resources[m.group(2)] = m.group(1)
            if line.startswith("[node "):
                node = line.split('"')[1]
                m = re.search(r'instance=ExtResource\("([^"]+)"\)', line)
                script = scene_root_script(res_path(resources[m.group(1)])) if m else None
            m = re.match(r'script = ExtResource\("([^"]+)"\)', line)
            if m:
                script = res_path(resources[m.group(1)])
            for name, flag in prop.findall(line):
                sets = script is not None and script_sets(script, name)
                (index.set_by if sets else index.read_by)[flag].add("%s (%s)" % (rel(path), node))


def quest_chart(quest_id, quest):
    lines = ["```mermaid", "flowchart TD"]
    lines.append('  start(["%s<br/><i>starts: %s</i>"])' % (mermaid_text(quest["title"]),
                                                        mermaid_text(describe(quest.get("started_when", {})))))
    previous = "start"
    for i, objective in enumerate(quest.get("objectives", [])):
        node = "o%d" % i
        lines.append('  %s["%s"]' % (node, mermaid_text(objective["text"])))
        lines.append('  %s --> %s' % (previous, node))
        previous = node
    lines.append('  done(["Done<br/><i>%s</i>"])' % mermaid_text(describe(quest.get("completed_when", {}))))
    lines.append("  %s --> done" % previous)
    for i, outcome in enumerate(quest.get("outcomes", [])):
        node = "r%d" % i
        lines.append('  %s["%s"]' % (node, mermaid_text(outcome["text"][:90] + ("…" if len(outcome["text"]) > 90 else ""))))
        lines.append('  done -. "%s" .-> %s' % (mermaid_text(describe(outcome.get("when", {}))), node))
    lines.append("```")
    return lines


def objective_table(quest):
    rows = ["| Step | Done when | Marker |", "|---|---|---|"]
    for objective in quest.get("objectives", []):
        rows.append("| %s | %s | %s |" % (objective["text"], describe(objective.get("done_when", {})),
                                         objective.get("marker", "")))
    return rows


def build():
    quests = json.load(open(os.path.join(GODOT, "quests", "quests.json"), encoding="utf-8"))
    index = Index()
    scan_dialogue(index)
    scan_quests(index, quests)
    scan_code(index)

    out = ["# Quest flow", "",
           "Generated by `tools/quest_flow.py` from the quest, dialogue, script and scene data. "
           "Don't edit by hand: change the game, then run `python3 tools/quest_flow.py`.", "",
           "Each quest's state is worked out from flags (and items) every time the journal looks, "
           "so a quest can complete in any order. Outcomes: the first one whose condition holds "
           "is the one the journal shows.", ""]
    main = [q for q in quests if quests[q].get("main")]
    side = [q for q in quests if not quests[q].get("main")]
    out += ["## Contents", ""]
    for group, ids in [("Main quests", main), ("Side quests", side)]:
        out.append("- %s: %s" % (group, ", ".join("[%s](#%s)" % (quests[q]["title"], q.replace("_", "-")) for q in ids)))
    out += ["- [Flag index](#flag-index)", ""]
    for group, ids in [("Main quests", main), ("Side quests", side)]:
        out += ["## " + group, ""]
        for quest_id in ids:
            quest = quests[quest_id]
            out += ['<a id="%s"></a>' % quest_id.replace("_", "-"), "",
                    "### %s (`%s`)" % (quest["title"], quest_id), "",
                    "Given by: %s. Starts when: %s. Done when: %s." % (
                        quest.get("giver", "?"), describe(quest.get("started_when", {})),
                        describe(quest.get("completed_when", {}))), ""]
            out += quest_chart(quest_id, quest) + [""]
            out += objective_table(quest) + [""]
    out += ["## Flag index", "",
            "Every flag, where it's set, and where it's checked. **⚠ never set** means nothing in "
            "the game sets it: a typo or a missing step. *(never checked)* is usually fine: a "
            "record for later, or for the tests.", "",
            "| Flag | Set by | Checked by |", "|---|---|---|"]
    for flag in sorted(set(index.set_by) | set(index.read_by)):
        set_by = sorted(index.set_by.get(flag, []))
        read_by = sorted(index.read_by.get(flag, []))
        runtime = [note for prefix, note in RUNTIME_FLAGS.items() if flag.startswith(prefix)]
        set_by = set_by or runtime
        mark = " ⚠ never set" if not set_by else (" (never checked)" if not read_by else "")
        out.append("| `%s`%s | %s | %s |" % (flag, mark, "<br>".join(set_by) or "–", "<br>".join(read_by) or "–"))
    return "\n".join(out) + "\n"


def main():
    text = build()
    if "--check" in sys.argv:
        problems = ["flag %s is checked but nothing sets it" % line.split("`")[1]
                    for line in text.splitlines() if "⚠ never set" in line and line.startswith("| `")]
        current = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if current != text:
            problems.append("docs/QUEST_FLOW.md is out of date: run python3 tools/quest_flow.py")
        for problem in problems:
            print("FAIL  " + problem)
        sys.exit(1 if problems else 0)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(text)
    print("wrote", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
