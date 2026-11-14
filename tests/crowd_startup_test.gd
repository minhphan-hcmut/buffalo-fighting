extends SceneTree
## Regression: the crowd mesh is baked from _ready callbacks while the root is still adding
## the main scene (the menu backdrop at game start), when the root refuses new children.
## The bake must not depend on the scene tree, or the stands stay empty for the session.

var failures := 0


func _initialize() -> void:
	LowPoly._crowd_meshes.clear()
	# Same situation as the game's start-up: bake from a _ready under root.add_child().
	var probe := Node.new()
	var script := GDScript.new()
	script.source_code = "extends Node\nvar heights: Array[float] = []\nfunc _ready() -> void:\n\tfor variant in 2:\n\t\theights.append(LowPoly.crowd_villager_mesh(variant).get_aabb().end.y)\n"
	script.reload()
	probe.set_script(script)
	var children_before := root.get_child_count()
	root.add_child(probe)
	_verify.call_deferred(probe, children_before + 1)


func _verify(probe: Node, expected_children: int) -> void:
	var heights: Array[float] = probe.get("heights")
	check(heights.size() == 2, "both crowd poses baked during start-up")
	for variant in heights.size():
		check(heights[variant] > 1.6 and heights[variant] < 2.0, "pose %d baked while the root was busy is ~1.7 m tall (%.2f)" % [variant, heights[variant]])
	check(root.get_child_count() == expected_children, "the bake leaves no node behind in the tree")
	probe.free()
	print("crowd_startup_test: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)
