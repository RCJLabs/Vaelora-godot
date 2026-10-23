extends StaticBody3D

# A bed: E opens the rest menu to sleep (and autosave).

var prompt := "Sleep"


func interact(_player: Node) -> void:
	RestMenu.open(self, false)
