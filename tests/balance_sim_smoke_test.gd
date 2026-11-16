extends SceneTree

const Sim := preload("res://tools/balance_sim.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var original := GameBalance.get_number("match_duration_s")
	GameBalance.values.match_duration_s = 12.0
	var simulation := Sim.Simulation.new(root)
	await physics_frame
	var samples: Array[Dictionary] = []
	for index in 4:
		samples.append(simulation.run_match("L03" if index % 2 == 0 else "L01", "NORMAL", "HARD", 42 + index % 2))
	var deterministic := samples[0] == samples[2] and samples[1] == samples[3]
	var complete := samples.all(func(result: Dictionary): return result.winner in [1, 2] and result.reason in ["FLEE", "TIME", "LOT"] and result.seconds > 0.0)
	var combat := samples.any(func(result: Dictionary): return result.moves[0].horn.uses + result.moves[0].dash.uses > 0)
	var summary := Sim.summarize(samples)
	var metrics: bool = summary.matches == 4 and summary.wins[0] + summary.wins[1] == 4
	for result in samples:
		for side in 2:
			var lost: float = GameBalance.get_number("spirit_max") - result.spirit[1 - side]
			metrics = metrics and is_equal_approx(result.damage[side].horn + result.damage[side].dash + result.damage[side].clash, lost)
			for meter in result.moves[side].values():
				metrics = metrics and meter.hits <= meter.opportunities
	simulation.dispose()
	GameBalance.values.match_duration_s = original
	if not deterministic or not complete or not combat or not metrics:
		push_error("Four real short matches must finish and repeat with the same seeds")
	print("BALANCE SMOKE: deterministic=", deterministic, " complete=", complete, " combat=", combat, " metrics=", metrics)
	quit(0 if deterministic and complete and combat and metrics else 1)
