extends Node

signal state_changed(state: String, detail: Dictionary)
signal load_started(source: Dictionary)
signal image_loaded(result: Dictionary)
signal image_failed(error_info: Dictionary)
signal slot_surface_changed(slot_name: String, descriptor: Dictionary)

const VERSION := "0.1.0"
const DEFAULT_SLOT := "primary"
const DEFAULT_VENDOR_FACTORY_CLASS := "AeroGodotImageVendorFactory"
const DEFAULT_VENDOR_BACKEND_ID := "godot_image"

const STATE_IDLE := "idle"
const STATE_LOADING := "loading"
const STATE_READY := "ready"
const STATE_ERROR := "error"

var _state: String = STATE_IDLE
var _last_result: Dictionary = {}
var _last_error: Dictionary = {}
var _loaded_texture: Texture2D = null
var _loaded_image: Image = null
var _loaded_source: Dictionary = {}
var _active_slot: String = DEFAULT_SLOT
var _slot_surfaces: Dictionary = {}
var _vendor_factory: RefCounted = null
var _vendor_loader: Node = null

func _ready() -> void:
	_ensure_vendor_loader()

func load_image(source: Dictionary, on_success: Callable = Callable(), on_failure: Callable = Callable()) -> Dictionary:
	var normalized := normalize_source(source)
	var vendor_ready := _ensure_vendor_loader()
	if not vendor_ready:
		return _fail(
			"image_backend_unavailable",
			"AeroImageLoader could not resolve the installed image backend factory.",
			{
				"source": normalized.duplicate(true),
				"vendor_factory_class": DEFAULT_VENDOR_FACTORY_CLASS,
			},
			on_failure
		)

	_active_slot = str(normalized.get("slot", DEFAULT_SLOT))
	_state = STATE_LOADING
	_last_error = {}
	_emit_state_changed(_compose_state_detail(normalized))
	load_started.emit(normalized.duplicate(true))

	var vendor_source := {
		"path": normalized.get("path", ""),
		"fit_mode": _fit_mode_for_source(normalized),
		"metadata": _build_vendor_metadata(normalized),
	}
	var vendor_result: Dictionary = _vendor_loader.call(
		"load_image",
		vendor_source,
		Callable(self, "_on_vendor_load_success").bind(on_success),
		Callable(self, "_on_vendor_load_failure").bind(on_failure)
	)
	if bool(vendor_result.get("success", false)):
		return _last_result.duplicate(true)
	return _last_error.duplicate(true)

func load_path(path: String, slot_name: String = DEFAULT_SLOT, maintain_aspect_ratio: bool = true, metadata: Dictionary = {}) -> Dictionary:
	return load_image({
		"path": path,
		"slot": slot_name,
		"maintain_aspect_ratio": maintain_aspect_ratio,
		"metadata": metadata.duplicate(true),
	})

func attach_slot_surface(slot_name: String, surface: TextureRect, maintain_aspect_ratio: bool = true) -> Dictionary:
	var normalized_slot := _normalize_slot_name(slot_name)
	if surface == null:
		return _fail(
			"image_invalid_surface",
			"AeroImageLoader cannot attach a null TextureRect surface.",
			{"slot": normalized_slot},
			Callable()
		)
	_slot_surfaces[normalized_slot] = {
		"surface": surface,
		"maintain_aspect_ratio": maintain_aspect_ratio,
	}
	if _loaded_texture != null and normalized_slot == _active_slot:
		_apply_loaded_texture_to_slot(normalized_slot)
	var descriptor := get_slot_descriptor(normalized_slot)
	slot_surface_changed.emit(normalized_slot, descriptor.duplicate(true))
	_emit_state_changed(_compose_state_detail())
	return _ok({"slot": normalized_slot, "attached": true, "maintain_aspect_ratio": maintain_aspect_ratio})

func detach_slot_surface(slot_name: String = "") -> Dictionary:
	var normalized_slot := _normalize_slot_name(slot_name if not slot_name.is_empty() else _active_slot)
	if not _slot_surfaces.has(normalized_slot):
		return _ok({"slot": normalized_slot, "attached": false})
	var slot_info: Dictionary = _slot_surfaces.get(normalized_slot, {})
	var surface: TextureRect = slot_info.get("surface", null)
	if surface != null:
		surface.texture = null
	_slot_surfaces.erase(normalized_slot)
	var descriptor := get_slot_descriptor(normalized_slot)
	slot_surface_changed.emit(normalized_slot, descriptor.duplicate(true))
	_emit_state_changed(_compose_state_detail())
	return _ok({"slot": normalized_slot, "attached": false})

func set_active_slot(slot_name: String) -> Dictionary:
	_active_slot = _normalize_slot_name(slot_name)
	if _loaded_texture != null:
		_apply_loaded_texture_to_slot(_active_slot)
	_emit_state_changed(_compose_state_detail())
	return _ok({"slot": _active_slot})

func set_slot_maintain_aspect_ratio(slot_name: String, maintain_aspect_ratio: bool) -> Dictionary:
	var normalized_slot := _normalize_slot_name(slot_name)
	if not _slot_surfaces.has(normalized_slot):
		return _fail(
			"image_slot_missing",
			"AeroImageLoader has no attached surface for the requested slot.",
			{"slot": normalized_slot},
			Callable()
		)
	var slot_info: Dictionary = _slot_surfaces.get(normalized_slot, {}).duplicate(true)
	slot_info["maintain_aspect_ratio"] = maintain_aspect_ratio
	_slot_surfaces[normalized_slot] = slot_info
	if _loaded_texture != null and normalized_slot == _active_slot:
		_apply_loaded_texture_to_slot(normalized_slot)
	var descriptor := get_slot_descriptor(normalized_slot)
	slot_surface_changed.emit(normalized_slot, descriptor.duplicate(true))
	_emit_state_changed(_compose_state_detail())
	return _ok({"slot": normalized_slot, "maintain_aspect_ratio": maintain_aspect_ratio})

func create_preview_surface(slot_name: String = DEFAULT_SLOT, maintain_aspect_ratio: bool = true) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	attach_slot_surface(slot_name, texture_rect, maintain_aspect_ratio)
	return texture_rect

func get_state() -> Dictionary:
	return {
		"state": _state,
		"detail": _compose_state_detail(),
	}

func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)

func get_last_error() -> Dictionary:
	return _last_error.duplicate(true)

func get_loaded_texture() -> Texture2D:
	return _loaded_texture

func get_loaded_source() -> Dictionary:
	return _loaded_source.duplicate(true)

func get_active_slot() -> String:
	return _active_slot

func get_slot_descriptor(slot_name: String) -> Dictionary:
	var normalized_slot := _normalize_slot_name(slot_name)
	var slot_info: Dictionary = _slot_surfaces.get(normalized_slot, {})
	var surface: TextureRect = slot_info.get("surface", null)
	return {
		"slot": normalized_slot,
		"attached": surface != null and is_instance_valid(surface),
		"maintain_aspect_ratio": bool(slot_info.get("maintain_aspect_ratio", true)),
		"has_texture": surface != null and is_instance_valid(surface) and surface.texture != null,
	}

func get_capabilities() -> Dictionary:
	var vendor_capabilities: Dictionary = {}
	if _ensure_vendor_loader() and _vendor_loader.has_method("get_capabilities"):
		vendor_capabilities = _vendor_loader.call("get_capabilities")
	return {
		"service": "image_loader",
		"backend": DEFAULT_VENDOR_BACKEND_ID,
		"backend_ready": _vendor_loader != null,
		"supports_slots": true,
		"supports_maintain_aspect_ratio": true,
		"supported_extensions": Array(vendor_capabilities.get("supported_extensions", ["png"])).duplicate(true),
		"supported_path_kinds": Array(vendor_capabilities.get("supported_path_kinds", [])).duplicate(true),
	}

func reset() -> void:
	_loaded_texture = null
	_loaded_image = null
	_loaded_source = {}
	_last_result = {}
	_last_error = {}
	_state = STATE_IDLE
	for slot_name in _slot_surfaces.keys():
		var slot_info: Dictionary = _slot_surfaces.get(slot_name, {})
		var surface: TextureRect = slot_info.get("surface", null)
		if surface != null and is_instance_valid(surface):
			surface.texture = null
	_emit_state_changed(_compose_state_detail())

static func normalize_source(source: Dictionary) -> Dictionary:
	var normalized := {
		"path": "",
		"slot": DEFAULT_SLOT,
		"maintain_aspect_ratio": true,
		"metadata": {},
	}
	for key in source.keys():
		normalized[key] = source[key]
	normalized["path"] = str(normalized.get("path", "")).strip_edges()
	normalized["slot"] = _normalize_slot_name(str(normalized.get("slot", DEFAULT_SLOT)))
	normalized["maintain_aspect_ratio"] = bool(normalized.get("maintain_aspect_ratio", true))
	if typeof(normalized.get("metadata", {})) != TYPE_DICTIONARY:
		normalized["metadata"] = {}
	return normalized

func _ensure_vendor_loader() -> bool:
	if _vendor_loader != null and is_instance_valid(_vendor_loader):
		return true
	var vendor_factory_script := _load_global_class_script(DEFAULT_VENDOR_FACTORY_CLASS)
	if vendor_factory_script == null:
		return false
	_vendor_factory = vendor_factory_script.new()
	if _vendor_factory == null:
		return false
	if not _vendor_factory.has_method("create_loader"):
		return false
	var loader_candidate: Variant = _vendor_factory.call("create_loader")
	if not (loader_candidate is Node):
		return false
	_vendor_loader = loader_candidate
	add_child(_vendor_loader)
	return true

func _load_global_class_script(target_class_name: String) -> GDScript:
	for class_info in ProjectSettings.get_global_class_list():
		if str(class_info.get("class", "")) == target_class_name:
			var path := str(class_info.get("path", ""))
			if path.is_empty():
				return null
			return load(path)
	return null

func _fit_mode_for_source(source: Dictionary) -> String:
	return "cover" if bool(source.get("maintain_aspect_ratio", true)) else "stretch"

func _build_vendor_metadata(source: Dictionary) -> Dictionary:
	var metadata: Dictionary = source.get("metadata", {}).duplicate(true)
	metadata["slot"] = source.get("slot", DEFAULT_SLOT)
	metadata["maintain_aspect_ratio"] = bool(source.get("maintain_aspect_ratio", true))
	return metadata

func _apply_loaded_texture_to_slot(slot_name: String) -> void:
	if _vendor_loader == null or _loaded_texture == null:
		return
	var normalized_slot := _normalize_slot_name(slot_name)
	if not _slot_surfaces.has(normalized_slot):
		return
	var slot_info: Dictionary = _slot_surfaces.get(normalized_slot, {})
	var surface: TextureRect = slot_info.get("surface", null)
	if surface == null or not is_instance_valid(surface):
		return
	var fit_mode := "cover" if bool(slot_info.get("maintain_aspect_ratio", true)) else "stretch"
	if _vendor_loader.has_method("apply_result_to_surface"):
		_vendor_loader.call("apply_result_to_surface", surface, _loaded_texture, fit_mode)
	else:
		surface.texture = _loaded_texture
		surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		surface.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if fit_mode == "cover" else TextureRect.STRETCH_SCALE

func _on_vendor_load_success(vendor_result: Dictionary, on_success: Callable) -> void:
	var detail: Dictionary = vendor_result.get("detail", {})
	_loaded_texture = detail.get("texture", null)
	_loaded_image = detail.get("image", null)
	var maintain_aspect_ratio := true
	if detail.has("source"):
		maintain_aspect_ratio = bool(detail.get("source", {}).get("metadata", {}).get("maintain_aspect_ratio", true))
	_loaded_source = {
		"path": str(detail.get("source", {}).get("path", "")),
		"slot": str(detail.get("source", {}).get("metadata", {}).get("slot", _active_slot)),
		"maintain_aspect_ratio": maintain_aspect_ratio,
		"metadata": detail.get("source", {}).get("metadata", {}).duplicate(true),
		"path_kind": detail.get("path_kind", ""),
	}
	_active_slot = _normalize_slot_name(str(_loaded_source.get("slot", _active_slot)))
	_apply_loaded_texture_to_slot(_active_slot)
	_state = STATE_READY
	_last_error = {}
	_last_result = _ok({
		"path": _loaded_source.get("path", ""),
		"slot": _active_slot,
		"maintain_aspect_ratio": maintain_aspect_ratio,
		"texture": _loaded_texture,
		"image": _loaded_image,
		"width": int(detail.get("width", 0)),
		"height": int(detail.get("height", 0)),
		"size": detail.get("size", Vector2i.ZERO),
		"path_kind": detail.get("path_kind", ""),
		"mime_type": detail.get("mime_type", ""),
		"surface_attached": bool(get_slot_descriptor(_active_slot).get("attached", false)),
		"backend_result": vendor_result.duplicate(true),
	})
	_emit_state_changed(_compose_state_detail())
	image_loaded.emit(_last_result.duplicate(true))
	if on_success.is_valid():
		on_success.call(_last_result.duplicate(true))

func _on_vendor_load_failure(vendor_error: Dictionary, on_failure: Callable) -> void:
	var detail: Dictionary = vendor_error.get("detail", {})
	var source_detail: Dictionary = detail.get("source", {})
	var metadata: Dictionary = source_detail.get("metadata", {})
	var maintain_aspect_ratio := bool(metadata.get("maintain_aspect_ratio", true))
	var slot_name := _normalize_slot_name(str(metadata.get("slot", _active_slot)))
	_loaded_texture = null
	_loaded_image = null
	_last_result = {}
	_state = STATE_ERROR
	_last_error = {
		"success": false,
		"code": str(vendor_error.get("code", "image_load_failed")),
		"message": str(vendor_error.get("message", "Image load failed.")),
		"detail": {
			"path": str(source_detail.get("path", detail.get("path", ""))),
			"slot": slot_name,
			"maintain_aspect_ratio": maintain_aspect_ratio,
			"backend_error": vendor_error.duplicate(true),
		},
	}
	_emit_state_changed(_compose_state_detail({
		"path": str(source_detail.get("path", detail.get("path", ""))),
		"slot": slot_name,
		"maintain_aspect_ratio": maintain_aspect_ratio,
	}))
	image_failed.emit(_last_error.duplicate(true))
	if on_failure.is_valid():
		on_failure.call(_last_error.duplicate(true))

func _compose_state_detail(overrides: Dictionary = {}) -> Dictionary:
	var width := 0
	var height := 0
	if _loaded_image != null:
		width = _loaded_image.get_width()
		height = _loaded_image.get_height()
	var detail := {
		"backend": DEFAULT_VENDOR_BACKEND_ID,
		"backend_ready": _vendor_loader != null,
		"active_slot": _active_slot,
		"slot_names": PackedStringArray(_slot_surfaces.keys()),
		"surface_attached": bool(get_slot_descriptor(_active_slot).get("attached", false)),
		"path": str(_loaded_source.get("path", "")),
		"maintain_aspect_ratio": bool(_loaded_source.get("maintain_aspect_ratio", true)),
		"width": width,
		"height": height,
	}
	for key in overrides.keys():
		detail[key] = overrides[key]
	return detail

func _emit_state_changed(detail: Dictionary) -> void:
	state_changed.emit(_state, detail.duplicate(true))

func _fail(code: String, message: String, detail: Dictionary, on_failure: Callable) -> Dictionary:
	_loaded_texture = null
	_loaded_image = null
	_last_result = {}
	_last_error = {
		"success": false,
		"code": code,
		"message": message,
		"detail": detail.duplicate(true),
	}
	_state = STATE_ERROR
	_emit_state_changed(_compose_state_detail(detail))
	image_failed.emit(_last_error.duplicate(true))
	if on_failure.is_valid():
		on_failure.call(_last_error.duplicate(true))
	return _last_error.duplicate(true)

func _ok(detail: Dictionary = {}) -> Dictionary:
	return {
		"success": true,
		"detail": detail.duplicate(true),
	}

static func _normalize_slot_name(slot_name: String) -> String:
	var normalized := slot_name.strip_edges()
	return normalized if not normalized.is_empty() else DEFAULT_SLOT
