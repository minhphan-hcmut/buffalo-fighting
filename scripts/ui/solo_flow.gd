class_name SoloFlow
extends Node
## Solo sequencing only. SessionState is the sole progress store; views own presentation.

var ceremony_layer: CeremonyView
var _host: Control
var _enter: Callable
var _go: Callable
var _prepare: Callable
var _hide_result: Callable
var _leave: Callable
var _change: Callable


func setup(host: Control, enter: Callable, go: Callable, prepare: Callable, hide_result: Callable, leave: Callable, change: Callable) -> void:
	_host = host
	_enter = enter
	_go = go
	_prepare = prepare
	_hide_result = hide_result
	_leave = leave
	_change = change


func start_season() -> void:
	_prepare.call()
	var rites: Array[StringName] = []
	if SessionState.begin_solo():
		rites.append(&"opening")
	rites.append_array(SessionState.take_rites_before(SessionState.level_id))
	play_rites(rites, _enter)


func select_free_play(level: StringName) -> void:
	SessionState.begin_free_play(level)
	_prepare.call()
	_enter.call()


func select_training(drill: StringName) -> void:
	SessionState.begin_training(drill)
	_prepare.call()
	_enter.call()


func set_unlimited_stamina(enabled: bool) -> void:
	SessionState.training_unlimited_stamina = enabled
	SessionState.save_settings()


func retry() -> void:
	SessionState.retry()
	_go.call()


func next_match() -> void:
	# Do not clear the last result until the rite has finished, or the overlay rebuilds.
	var rites := SessionState.take_rites_before(SessionState.level_id)
	if not rites.is_empty():
		_hide_result.call()
	play_rites(rites, _begin_next)


func _begin_next() -> void:
	SessionState.begin_solo()
	_go.call()


func return_to_menu() -> void:
	SessionState.return_to_menu()
	_leave.call()


func change_free_play_match() -> void:
	_change.call()
	return_to_menu()


func result_data() -> Dictionary:
	var won := SessionState.last_winner == 1
	var final_win := won and not SessionState.free_play and SessionState.last_match_level == SessionState.SOLO_LEVELS[-1]
	return {
		"level": SessionState.last_match_level,
		"won": won,
		"final_win": final_win,
		"free_play": SessionState.free_play,
		"reason": SessionState.last_reason,
		"next_level": SessionState.level_id,
		"culture": select_card(final_win)
	}


func select_card(final_win: bool) -> Dictionary:
	var card: Dictionary = {}
	if SessionState.mode == &"SOLO" and not SessionState.training:
		card = CultureCards.next_card(SessionState.culture_cards_seen, final_win)
	if not card.is_empty():
		# Reserve once per result; notebook award still waits for actual visibility.
		SessionState.culture_cards_seen.append(StringName(card.id))
	return {"card": card, "count": SessionState.culture_cards_seen.size()}


func card_visible(card_id: StringName) -> void:
	CultureCards.mark_shown(card_id)


func play_rites(rites: Array[StringName], done: Callable) -> void:
	clear_rite()
	if rites.is_empty():
		if done.is_valid():
			done.call()
		return
	ceremony_layer = CeremonyView.create(rites[0])
	ceremony_layer.finished.connect(_rite_finished.bind(rites.slice(1), done), CONNECT_ONE_SHOT)
	_host.add_child(ceremony_layer)


func _rite_finished(rest: Array[StringName], done: Callable) -> void:
	play_rites(rest, done)


func closing(done: Callable) -> void:
	var rites: Array[StringName] = [&"closing"]
	play_rites(rites, done)


func clear_rite() -> void:
	if is_instance_valid(ceremony_layer):
		ceremony_layer.hide()
		ceremony_layer.queue_free()
	ceremony_layer = null


func _exit_tree() -> void:
	# Sibling ceremony nodes are freed by the host, no parent mutation during teardown.
	ceremony_layer = null
