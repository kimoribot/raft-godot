extends Control
class_name BuildingMenu

## Building Menu UI for Raft
## Displays buildable items, costs, and handles selection

signal build_item_selected(item_type: String)
signal menu_closed

# UI References
@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var category_tabs: TabContainer = $Panel/VBoxContainer/CategoryTabs
@onready var item_list: ItemList = $Panel/VBoxContainer/CategoryTabs/AllItems/ItemList
@onready var details_panel: Panel = $Panel/VBoxContainer/DetailsPanel
@onready var item_name_label: Label = $Panel/VBoxContainer/DetailsPanel/ItemName
@onready var item_description_label: Label = $Panel/VBoxContainer/DetailsPanel/ItemDescription
@onready var cost_label: Label = $Panel/VBoxContainer/DetailsPanel/CostLabel
@onready var build_button: Button = $Panel/VBoxContainer/DetailsPanel/BuildButton
@onready var cancel_button: Button = $Panel/VBoxContainer/CancelButton

# Theme
var selected_color: Color = Color(0.2, 0.6, 0.2, 0.8)  # Green
var affordable_color: Color = Color(0.3, 0.8, 0.3, 1.0)  # Bright green
var expensive_color: Color = Color(0.8, 0.3, 0.3, 1.0)  # Red
var default_color: Color = Color(0.5, 0.5, 0.5, 1.0)  # Gray

# State
var building_system: RaftBuildingSystem
var current_category: String = "All"
var selected_item: String = ""
var is_visible_flag: bool = false

# Category tabs storage
var category_panels: Dictionary = {}

func _ready() -> void:
	_setup_ui()
	_connect_signals()


func _setup_ui() -> void:
	# Create category tabs dynamically based on building system categories
	if building_system:
		_create_category_tabs()
	
	# Setup details panel visibility
	details_panel.visible = false
	
	# Initial population
	if building_system:
		_populate_item_list("All")


func _connect_signals() -> void:
	if build_button:
		build_button.pressed.connect(_on_build_pressed)
	
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	
	if item_list:
		item_list.item_selected.connect(_on_item_selected)
		item_list.item_activated.connect(_on_item_activated)


func _create_category_tabs() -> void:
	if not building_system:
		return
	
	# Remove existing category tabs (keep "All" as fallback)
	var categories = building_system.get_build_categories()
	
	# Ensure we have at least the default categories
	var all_categories = ["All", "Raft", "Storage", "Survival", "Decor"]
	
	for cat in all_categories:
		if not category_panels.has(cat):
			var scroll = ScrollContainer.new()
			scroll.name = cat
			scroll.visible = (cat == "All")
			
			var list = ItemList.new()
			list.name = "ItemList"
			list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			list.size_flags_vertical = Control.SIZE_EXPAND_FILL
			list.item_selected.connect(_on_item_selected_from_category.bind(cat))
			list.item_activated.connect(_on_item_activated_from_category.bind(cat))
			
			scroll.add_child(list)
			category_tabs.add_child(scroll)
			category_panels[cat] = {"scroll": scroll, "list": list}
	
	# Populate each category
	for cat in all_categories:
		if category_panels.has(cat):
			_populate_category(cat)


func _populate_category(category: String) -> void:
	if not building_system:
		return
	
	var panel_data = category_panels.get(category)
	if not panel_data:
		return
	
	var list: ItemList = panel_data.get("list")
	if not list:
		return
	
	list.clear()
	
	var items: Array[String]
	if category == "All":
		items = building_system.buildable_items.keys()
	else:
		items = building_system.get_items_by_category(category)
	
	for item_type in items:
		var info = building_system.get_item_info(item_type)
		var display_name = info.get("display_name", item_type)
		
		# Check affordability
		var can_afford = building_system._can_afford_item(item_type)
		
		# Add item to list (with icon indicator for affordability)
		var icon_index = -1  # No icon, just text
		list.add_item(display_name, null, false)
		
		# Color code based on affordability
		var color = affordable_color if can_afford else expensive_color
		list.set_item_custom_fg_color(list.item_count - 1, color)


func _populate_item_list(filter_category: String = "All") -> void:
	if not building_system:
		return
	
	item_list.clear()
	
	var items: Array[String]
	if filter_category == "All":
		items = building_system.buildable_items.keys()
	else:
		items = building_system.get_items_by_category(filter_category)
	
	for item_type in items:
		var info = building_system.get_item_info(item_type)
		var display_name = info.get("display_name", item_type)
		var can_afford = building_system._can_afford_item(item_type)
		
		item_list.add_item(display_name)
		
		# Color code based on affordability
		var color = affordable_color if can_afford else expensive_color
		item_list.set_item_custom_fg_color(item_list.item_count - 1, color)


func _update_affordability() -> void:
	# Refresh the item list to update affordability colors
	if current_category == "All":
		_populate_item_list("All")
	else:
		_populate_category(current_category)
	
	# Also update details panel if an item is selected
	if selected_item:
		_update_details_panel(selected_item)


func _update_details_panel(item_type: String) -> void:
	if not building_system:
		return
	
	var info = building_system.get_item_info(item_type)
	if info.is_empty():
		details_panel.visible = false
		return
	
	details_panel.visible = true
	
	# Update labels
	item_name_label.text = info.get("display_name", item_type)
	item_description_label.text = info.get("description", "")
	
	# Build cost string
	var cost = info.get("cost", {})
	var cost_text = "Cost: "
	var cost_items: Array[String] = []
	var can_afford = true
	
	for item_type_key in cost.keys():
		var amount = cost[item_type_key]
		var item_name = Recipes.get_item_type_name(item_type_key)
		
		# Check affordability
		var available = _get_item_count(item_type_key)
		var item_color = "✓" if available >= amount else "✗"
		if available < amount:
			can_afford = false
		
		cost_items.append("%s %d %s" % [item_color, amount, item_name])
	
	if cost_items.is_empty():
		cost_text = "Cost: Free"
	else:
		cost_text = "Cost:\n" + "\n".join(cost_items)
	
	cost_label.text = cost_text
	
	# Update build button
	build_button.disabled = not can_afford
	build_button.text = "Build" if can_afford else "Can't Afford"


func _get_item_count(item_type) -> int:
	if not building_system:
		return 0
	
	var inv = get_tree().get_first_node_in_group("inventory")
	if inv:
		if inv.has_method("get_item_count"):
			return inv.get_item_count(item_type)
		elif inv.has_method("get_item_quantity"):
			return inv.get_item_quantity(item_type)
	
	return 0


# ========== SIGNALS ==========

func _on_item_selected(index: int) -> void:
	var items = building_system.buildable_items.keys()
	if index >= 0 and index < items.size():
		selected_item = items[index]
		_update_details_panel(selected_item)


func _on_item_activated(index: int) -> void:
	_on_item_selected(index)
	_on_build_pressed()


func _on_item_selected_from_category(index: int, category: String) -> void:
	current_category = category
	var items = building_system.get_items_by_category(category)
	if index >= 0 and index < items.size():
		selected_item = items[index]
		_update_details_panel(selected_item)


func _on_item_activated_from_category(index: int, category: String) -> void:
	_on_item_selected_from_category(index, category)
	_on_build_pressed()


func _on_build_pressed() -> void:
	if not selected_item.is_empty():
		build_item_selected.emit(selected_item)
		hide()


func _on_cancel_pressed() -> void:
	menu_closed.emit()
	hide()


func _on_category_tab_changed(tab_name: String) -> void:
	current_category = tab_name
	selected_item = ""
	details_panel.visible = false
	
	# Switch to the selected category's item list
	_populate_item_list(tab_name)


# ========== PUBLIC METHODS ==========

## Initialize the menu with building system reference
func initialize(system: RaftBuildingSystem) -> void:
	building_system = system
	_setup_ui()


## Show the building menu
func show_menu() -> void:
	visible = true
	is_visible_flag = true
	_update_affordability()


## Hide the building menu
func hide_menu() -> void:
	visible = false
	is_visible_flag = false
	menu_closed.emit()


## Toggle menu visibility
func toggle() -> void:
	if is_visible_flag:
		hide_menu()
	else:
		show_menu()


## Refresh affordability display (call after inventory changes)
func refresh() -> void:
	_update_affordability()


# ========== INPUT HANDLING ==========

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Close on escape
	if event.is_action_pressed("ui_cancel"):
		hide_menu()
		get_viewport().set_input_as_handled()


# ========== SETUP FROM SCENE ==========

## Create the UI programmatically if not set up in editor
static func create_default_ui() -> Control:
	var control = Control.new()
	control.set_script(load("res://systems/building_menu.gd"))
	control.name = "BuildingMenu"
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	
	# Panel
	var panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_right = 0.4
	panel.anchor_bottom = 0.8
	panel.position = Vector2(50, 50)
	control.add_child(panel)
	
	# VBox inside panel
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "Build"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Category tabs
	var tabs = TabContainer.new()
	tabs.name = "CategoryTabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tabs)
	
	# Add "All" tab
	var all_scroll = ScrollContainer.new()
	all_scroll.name = "All"
	var all_list = ItemList.new()
	all_list.name = "ItemList"
	all_scroll.add_child(all_list)
	tabs.add_child(all_scroll)
	
	# Details panel
	var details = Panel.new()
	details.name = "DetailsPanel"
	details.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(details)
	
	# Details labels
	var details_vbox = VBoxContainer.new()
	details.add_child(details_vbox)
	
	var item_name = Label.new()
	item_name.name = "ItemName"
	item_name.text = "Select an item"
	details_vbox.add_child(item_name)
	
	var desc = Label.new()
	desc.name = "ItemDescription"
	desc.text = ""
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	details_vbox.add_child(desc)
	
	var cost = Label.new()
	cost.name = "CostLabel"
	cost.text = "Cost: "
	details_vbox.add_child(cost)
	
	var build_btn = Button.new()
	build_btn.name = "BuildButton"
	build_btn.text = "Build"
	build_btn.disabled = true
	details_vbox.add_child(build_btn)
	
	# Cancel button
	var cancel = Button.new()
	cancel.name = "CancelButton"
	cancel.text = "Cancel"
	vbox.add_child(cancel)
	
	return control
