extends CanvasLayer

@onready var health_label = $Panel/HBox/HealthLabel
@onready var hunger_label = $Panel/HBox/HungerLabel
@onready var thirst_label = $Panel/HBox/ThirstLabel
@onready var inventory_label = $Panel/HBox/InventoryLabel
@onready var message_label = $MessageLabel

var message_timer = 0.0

func _process(delta):
	if message_timer > 0:
		message_timer -= delta
		if message_timer <= 0:
			message_label.text = ""

func update_stats(health: int, hunger: int, thirst: int):
	health_label.text = "Health: " + str(health)
	hunger_label.text = "Hunger: " + str(hunger)
	thirst_label.text = "Thirst: " + str(thirst)

func update_inventory(items: Array):
	if items.is_empty():
		inventory_label.text = "Inventory: Empty"
	else:
		inventory_label.text = "Inventory: " + str(items.size()) + " items"

func show_message(text: String, duration: float = 3.0):
	message_label.text = text
	message_timer = duration
