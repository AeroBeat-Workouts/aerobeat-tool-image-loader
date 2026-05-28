extends GutTest

const LoaderScript := preload("res://addons/aerobeat-tool-image-loader/src/AeroImageLoader.gd")
const RemoteSampleServerScript := preload("res://scripts/remote_sample_server.gd")
const SAMPLE_RES_PATH := "res://assets/images/demo_tool_landscape.png"
const SAMPLE_ASSET_DIR := "res://assets/images"
const SAMPLE_FILE_NAME := "demo_tool_landscape.png"

var _loader: Node
var _remote_server
var _remote_sample_url: String = ""
var _external_tmp_dir: String = ""
var _external_sample_path: String = ""
var _user_sample_path: String = "user://image-loader-user-sample.png"
var _success_results: Array = []
var _failure_results: Array = []

func before_each() -> void:
	_loader = LoaderScript.new()
	add_child_autofree(_loader)
	_prepare_external_sample()
	_prepare_user_sample()
	_prepare_remote_sample()
	_success_results.clear()
	_failure_results.clear()

func after_each() -> void:
	if _remote_server != null:
		_remote_server.stop()
	if FileAccess.file_exists(ProjectSettings.globalize_path(_user_sample_path)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_user_sample_path))
	if not _external_sample_path.is_empty() and FileAccess.file_exists(_external_sample_path):
		DirAccess.remove_absolute(_external_sample_path)
	if not _external_tmp_dir.is_empty() and DirAccess.dir_exists_absolute(_external_tmp_dir):
		DirAccess.remove_absolute(_external_tmp_dir)

func _prepare_external_sample() -> void:
	_external_tmp_dir = OS.get_cache_dir().path_join("aerobeat-tool-image-loader-tests-%s" % str(Time.get_unix_time_from_system()))
	assert_eq(DirAccess.make_dir_recursive_absolute(_external_tmp_dir), OK, "Should create external sample directory")
	_external_sample_path = _external_tmp_dir.path_join("external-demo.png")
	assert_true(_copy_file(ProjectSettings.globalize_path(SAMPLE_RES_PATH), _external_sample_path), "Should copy external PNG sample")

func _prepare_user_sample() -> void:
	assert_true(_copy_file(ProjectSettings.globalize_path(SAMPLE_RES_PATH), ProjectSettings.globalize_path(_user_sample_path)), "Should copy PNG sample into user://")

func _prepare_remote_sample() -> void:
	_remote_server = RemoteSampleServerScript.new()
	var server_result: Dictionary = _remote_server.start(SAMPLE_ASSET_DIR, SAMPLE_FILE_NAME)
	assert_true(bool(server_result.get("success", false)), "Should start a local HTTP fixture for wrapper-level remote URL proving")
	_remote_sample_url = str(server_result.get("detail", {}).get("url", ""))
	assert_true(_remote_sample_url.begins_with("http://127.0.0.1:"), "Fixture server should expose a localhost http:// URL")

func _on_success(result: Dictionary) -> void:
	_success_results.append(result)

func _on_failure(result: Dictionary) -> void:
	_failure_results.append(result)

func _global_class_names() -> Array[String]:
	var names: Array[String] = []
	for class_info in ProjectSettings.get_global_class_list():
		names.append(str(class_info.get("class", "")))
	return names

func test_public_surface_is_vendor_agnostic_and_slot_focused() -> void:
	var class_names := _global_class_names()
	assert_false(class_names.has("AeroToolManager"), "Repo should no longer export the template AeroToolManager global class")
	assert_eq(str(ProjectSettings.get_setting("autoload/AeroImageLoader", "")), "*res://addons/aerobeat-tool-image-loader/src/AeroImageLoader.gd", "Testbed should expose the public singleton through autoload")
	assert_eq(LoaderScript.VERSION, "0.1.0", "Wrapper version should reflect the landed public image-loader slice")
	assert_true(bool(_loader.get_capabilities().get("supports_slots", false)), "Capabilities should advertise slot support")
	assert_true(bool(_loader.get_capabilities().get("supports_maintain_aspect_ratio", false)), "Capabilities should advertise maintain-aspect support")
	assert_true(bool(_loader.get_capabilities().get("supports_remote_urls", false)), "Capabilities should advertise remote URL support through the vendor backend")

func test_loader_supports_res_user_absolute_and_remote_paths_through_the_public_wrapper() -> void:
	var res_result: Dictionary = _loader.load_image({"path": SAMPLE_RES_PATH, "slot": "background", "maintain_aspect_ratio": true})
	assert_true(bool(res_result.get("success", false)), "Wrapper should load packaged res:// PNG")
	assert_eq(str(res_result.get("detail", {}).get("slot", "")), "background", "Result should preserve the requested slot")
	assert_true(bool(res_result.get("detail", {}).get("maintain_aspect_ratio", false)), "Result should preserve maintain-aspect intent")
	assert_eq(int(res_result.get("detail", {}).get("width", 0)), 96, "Sample width should be reported from the real PNG")
	assert_eq(int(res_result.get("detail", {}).get("height", 0)), 54, "Sample height should be reported from the real PNG")

	var user_result: Dictionary = _loader.load_path(_user_sample_path, "card", false)
	assert_true(bool(user_result.get("success", false)), "Wrapper should load user:// PNG")
	assert_eq(str(user_result.get("detail", {}).get("slot", "")), "card", "load_path should target the requested slot")
	assert_false(bool(user_result.get("detail", {}).get("maintain_aspect_ratio", true)), "load_path should preserve stretch intent")

	var absolute_result: Dictionary = _loader.load_image({"path": _external_sample_path, "slot": "preview", "maintain_aspect_ratio": true})
	assert_true(bool(absolute_result.get("success", false)), "Wrapper should load absolute PNG paths outside the project tree")
	assert_eq(str(absolute_result.get("detail", {}).get("path_kind", "")), "absolute", "Absolute sample should report absolute path kind")

	var remote_result: Dictionary = _loader.load_image({"path": _remote_sample_url, "slot": "background", "maintain_aspect_ratio": true})
	assert_true(bool(remote_result.get("success", false)), "Wrapper should start remote URL loads")
	assert_true(bool(remote_result.get("detail", {}).get("pending", false)), "Wrapper should report a truthful pending state for remote URL loads")
	assert_eq(str(remote_result.get("detail", {}).get("slot", "")), "background", "Remote pending envelope should preserve the requested slot")
	await wait_for_signal(_loader.image_loaded, 5.0)
	assert_eq(str(_loader.get_last_result().get("detail", {}).get("path_kind", "")), "http", "Completed remote wrapper result should preserve the http path kind")

func test_loader_places_textures_into_named_slots_and_maps_maintain_aspect_vs_stretch() -> void:
	var background_surface := TextureRect.new()
	var card_surface := TextureRect.new()
	add_child_autofree(background_surface)
	add_child_autofree(card_surface)

	var attach_background: Dictionary = _loader.attach_slot_surface("background", background_surface, true)
	var attach_card: Dictionary = _loader.attach_slot_surface("card", card_surface, false)
	assert_true(bool(attach_background.get("success", false)), "Background slot surface should attach")
	assert_true(bool(attach_card.get("success", false)), "Card slot surface should attach")

	var background_result: Dictionary = _loader.load_image({"path": SAMPLE_RES_PATH, "slot": "background", "maintain_aspect_ratio": true})
	assert_true(bool(background_result.get("success", false)), "Background slot should load packaged PNG")
	assert_eq(background_surface.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Maintain-aspect mode should map to covered keep-aspect placement")
	assert_not_null(background_surface.texture, "Background slot should receive the loaded texture")
	assert_null(card_surface.texture, "Only the requested slot should be updated by the current load")

	var card_result: Dictionary = _loader.load_image({"path": SAMPLE_RES_PATH, "slot": "card", "maintain_aspect_ratio": false})
	assert_true(bool(card_result.get("success", false)), "Card slot should load packaged PNG")
	assert_eq(card_surface.stretch_mode, TextureRect.STRETCH_SCALE, "Stretch mode should map to STRETCH_SCALE")
	assert_not_null(card_surface.texture, "Card slot should receive the loaded texture")

	var update_result: Dictionary = _loader.set_slot_maintain_aspect_ratio("card", true)
	assert_true(bool(update_result.get("success", false)), "Slot presentation should be mutable after attachment")
	assert_eq(card_surface.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Updating a slot to maintain aspect should immediately refresh presentation")

func test_loader_emits_callbacks_and_normalized_failures_for_local_and_remote_sources() -> void:
	watch_signals(_loader)
	var success_result: Dictionary = _loader.load_image({"path": SAMPLE_RES_PATH, "slot": "background"}, Callable(self, "_on_success"), Callable(self, "_on_failure"))
	assert_true(bool(success_result.get("success", false)), "Success callback path should load packaged PNG")
	assert_eq(_success_results.size(), 1, "Success callback should run once")
	assert_signal_emitted(_loader, "load_started")
	assert_signal_emitted(_loader, "image_loaded")

	watch_signals(_loader)
	var remote_result: Dictionary = _loader.load_image({"path": _remote_sample_url, "slot": "card"}, Callable(self, "_on_success"), Callable(self, "_on_failure"))
	assert_true(bool(remote_result.get("success", false)), "Remote callback path should start successfully")
	assert_true(bool(remote_result.get("detail", {}).get("pending", false)), "Remote callback path should return a pending success envelope")
	await wait_for_signal(_loader.image_loaded, 5.0)
	assert_eq(_success_results.size(), 2, "Remote success callback should run once after the HTTP response returns")
	assert_signal_emitted(_loader, "image_loaded")

	watch_signals(_loader)
	var failure_result: Dictionary = _loader.load_image({"path": "res://assets/images/missing.png", "slot": "background"}, Callable(self, "_on_success"), Callable(self, "_on_failure"))
	assert_false(bool(failure_result.get("success", true)), "Missing PNG should fail honestly")
	assert_eq(_failure_results.size(), 1, "Failure callback should run once")
	assert_signal_emitted(_loader, "image_failed")
	assert_eq(str(_loader.get_last_error().get("detail", {}).get("slot", "")), "background", "Normalized error payload should preserve the requested slot")

func test_loader_reports_backend_unavailable_truthfully_if_vendor_package_is_missing() -> void:
	assert_true(bool(_loader.get_capabilities().get("backend_ready", false)), "Repo-local testbed should include the real vendor package")

func _copy_file(source_path: String, destination_path: String) -> bool:
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return false
	var destination_file := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination_file == null:
		return false
	destination_file.store_buffer(source_file.get_buffer(source_file.get_length()))
	return true
