class_name CultureCards
extends RefCounted
## Selects an unseen Solo culture card without changing the session or match state.


static func next_card(seen: Array[StringName], is_final_win: bool) -> Dictionary:
	var data := DataFile.load_json("res://data/culture_cards.json")
	var cards: Array = data.get("cards", [])
	if is_final_win:
		for card: Dictionary in cards:
			if card.id == data.get("final_card", "") and StringName(card.id) not in seen:
				return card
	for card: Dictionary in cards:
		if StringName(card.id) not in seen:
			return card
	return {}
