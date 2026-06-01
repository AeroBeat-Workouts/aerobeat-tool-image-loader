extends Control

const SAMPLE_RES_PATH := "res://assets/images/demo_tool_landscape.png"
const SAMPLE_EXTERNAL_DIR_NAME := "aerobeat-tool-image-loader-testbed"
const SAMPLE_ASSET_DIR := "res://assets/images"
const SAMPLE_FILE_NAME := "demo_tool_landscape.png"
const FIT_MODE_OPTIONS := ["stretch", "contain", "cover"]
const RemoteSampleServerScript := preload("res://scripts/remote_sample_server.gd")

@onready var slot_selector: OptionButton = %SlotSelector
@onready var fit_mode_selector: OptionButton = %FitModeSelector
@onready var path_label: Label = %PathLabel
@onready var status_label: Label = %StatusLabel
@onready var detail_label: Label = %DetailLabel
@onready var background_surface: TextureRect = %BackgroundSurface
@onready var card_surface: TextureRect = %CardSurface
@onready var file_dialog: FileDialog = %FileDialog

var _remote_server
var _user_sample_path: String = ""
var _external_sample_path: String = ""
var _remote_sample_url: String = ""

func _ready() -> void:
	AeroImageLoader.reset()
	AeroImageLoader.attach_slot_surface("background", background_surface, "cover")
	AeroImageLoader.attach_slot_surface("card", card_surface, "stretch")
	AeroImageLoader.state_changed.connect(_on_state_changed)
	AeroImageLoader.image_loaded.connect(_on_image_loaded)
	AeroImageLoader.image_failed.connect(_on_image_failed)
	_configure_slot_selector()
	_configure_fit_mode_selector()
	_prepare_runtime_samples()
	path_label.text = SAMPLE_RES_PATH
	status_label.text = "Ready to place .png into the background or card slot from local paths or remote http/https URLs."
	detail_label.text = "Public contract: slot + fit_mode selection. Backend fetch/decode details stay hidden."
	_load_path(SAMPLE_RES_PATH)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _remote_server != null:
		_remote_server.stop()

func _configure_slot_selector() -> void:
	slot_selector.clear()
	slot_selector.add_item("background")
	slot_selector.add_item("card")
	slot_selector.select(0)

func _configure_fit_mode_selector() -> void:
	fit_mode_selector.clear()
	for fit_mode in FIT_MODE_OPTIONS:
		fit_mode_selector.add_item(fit_mode)
	fit_mode_selector.select(FIT_MODE_OPTIONS.find("cover"))

func _prepare_runtime_samples() -> void:
	var source_path := ProjectSettings.globalize_path(SAMPLE_RES_PATH)
	_user_sample_path = ProjectSettings.globalize_path("user://demo_tool_landscape.png")
	if FileAccess.file_exists(source_path):
		_copy_file(source_path, _user_sample_path)
		var external_dir := OS.get_cache_dir().path_join(SAMPLE_EXTERNAL_DIR_NAME)
		DirAccess.make_dir_recursive_absolute(external_dir)
		_external_sample_path = external_dir.path_join("demo_tool_landscape.png")
		_copy_file(source_path, _external_sample_path)
	_remote_server = RemoteSampleServerScript.new()
	var remote_server_result: Dictionary = _remote_server.start(SAMPLE_ASSET_DIR, SAMPLE_FILE_NAME)
	if bool(remote_server_result.get("success", false)):
		_remote_sample_url = str(remote_server_result.get("detail", {}).get("url", ""))
	else:
		status_label.text = "Remote sample server unavailable; local-path proving still works."

func _selected_slot() -> String:
	return slot_selector.get_item_text(slot_selector.selected)

func _load_path(path: String) -> void:
	path_label.text = path
	var slot_name := _selected_slot()
	var fit_mode := _selected_fit_mode()
	AeroImageLoader.set_active_slot(slot_name)
	AeroImageLoader.set_slot_fit_mode(slot_name, fit_mode)
	AeroImageLoader.load_image({
		"path": path,
		"slot": slot_name,
		"fit_mode": fit_mode,
	})

func _on_pick_file_pressed() -> void:
	file_dialog.popup_centered_ratio(0.8)

func _on_load_sample_res_pressed() -> void:
	_load_path(SAMPLE_RES_PATH)

func _on_load_sample_user_pressed() -> void:
	_load_path("user://demo_tool_landscape.png")

func _on_load_sample_absolute_pressed() -> void:
	if not _external_sample_path.is_empty():
		_load_path(_external_sample_path)

func _on_load_sample_remote_pressed() -> void:
	if _remote_sample_url.is_empty():
		status_label.text = "Remote sample URL unavailable."
		return
	_load_path(_remote_sample_url)

func _on_slot_selector_item_selected(_index: int) -> void:
	var slot_name := _selected_slot()
	var descriptor := AeroImageLoader.get_slot_descriptor(slot_name)
	fit_mode_selector.select(_fit_mode_index(str(descriptor.get("fit_mode", "cover"))))
	_refresh_detail_label(AeroImageLoader.get_state())

func _on_fit_mode_selector_item_selected(_index: int) -> void:
	AeroImageLoader.set_slot_fit_mode(_selected_slot(), _selected_fit_mode())
	_refresh_detail_label(AeroImageLoader.get_state())

func _on_file_dialog_file_selected(path: String) -> void:
	_load_path(path)

func _on_state_changed(_state: String, _detail: Dictionary) -> void:
	_refresh_detail_label(AeroImageLoader.get_state())

func _on_image_loaded(result: Dictionary) -> void:
	var detail: Dictionary = result.get("detail", {})
	status_label.text = "Loaded %s into %s (fit_mode=%s, kind=%s)." % [
		str(detail.get("path", "")),
		str(detail.get("slot", "")),
		str(detail.get("fit_mode", "cover")),
		str(detail.get("path_kind", "unknown")),
	]
	_refresh_detail_label(AeroImageLoader.get_state())

func _on_image_failed(error_info: Dictionary) -> void:
	status_label.text = "Load failed: %s" % str(error_info.get("message", "Unknown error"))
	_refresh_detail_label(AeroImageLoader.get_state())

func _refresh_detail_label(state_snapshot: Dictionary) -> void:
	var detail: Dictionary = state_snapshot.get("detail", {})
	detail_label.text = "State: %s | Slot: %s | fit_mode: %s | Size: %sx%s | Surface attached: %s" % [
		str(state_snapshot.get("state", AeroImageLoader.STATE_IDLE)),
		str(detail.get("active_slot", "")),
		str(detail.get("fit_mode", "cover")),
		str(detail.get("width", 0)),
		str(detail.get("height", 0)),
		str(detail.get("surface_attached", false)),
	]

func _selected_fit_mode() -> String:
	return fit_mode_selector.get_item_text(fit_mode_selector.selected)

func _fit_mode_index(fit_mode: String) -> int:
	var index := FIT_MODE_OPTIONS.find(fit_mode)
	return index if index >= 0 else FIT_MODE_OPTIONS.find("cover")

func _copy_file(source_path: String, destination_path: String) -> bool:
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return false
	var destination_file := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination_file == null:
		return false
	destination_file.store_buffer(source_file.get_buffer(source_file.get_length()))
	return true
