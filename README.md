# AeroBeat Image Loader

This repo hosts the vendor-agnostic image-loading singleton for the AeroBeat tool lane.

`AeroImageLoader` stays consumer-facing and backend-neutral: callers talk in terms of image paths, slot names, and a shared 3-state `fit_mode` contract. The current truthful implementation resolves the landed `aerobeat-vendor-godot-image` backend at runtime and uses it as the thin PNG-loading/runtime surface.

## Current contract scope

- `src/AeroImageLoader.gd`
  - singleton/autoload-friendly public image-loading service
  - vendor-factory resolution at runtime through the installed `AeroGodotImageVendorFactory` global class
  - slot-aware surface attachment via `attach_slot_surface(slot_name, texture_rect, fit_mode := "cover")`
  - vendor-agnostic load requests via `load_image({...})` or `load_path(...)`
  - canonical public fit-mode vocabulary: `stretch`, `contain`, `cover`
  - temporary compatibility seam for legacy callers that still send `maintain_aspect_ratio` or call `set_slot_maintain_aspect_ratio(...)`
- `.testbed/assets/images/demo_tool_landscape.png`
  - checked-in PNG sample used by the hidden proving surface and automated tests
- hidden `.testbed/`
  - autoload wiring for `AeroImageLoader`
  - file-picker/manual proving scene that exercises slot placement + stretch/contain/cover through the public singleton only
  - repo-local GUT tests covering the wrapper contract against the real vendor backend

## Public surface

Example:

```gdscript
AeroImageLoader.attach_slot_surface("background", $BackgroundTextureRect, "cover")

var result := AeroImageLoader.load_image({
	"path": "res://assets/images/demo_tool_landscape.png",
	"slot": "background",
	"fit_mode": "contain",
	"metadata": {"usage": "environment_background"},
})

if not result.get("success", false):
	push_error(result.get("message", "Image load failed"))
```

Consumers choose:

- which **slot** should receive the image
- which **fit mode** should drive placement: `stretch`, `contain`, or `cover`
- a concrete local path (`res://`, `user://`, project-relative, absolute device path, or supported remote URL)

### Temporary compatibility seam

This repo still accepts legacy `maintain_aspect_ratio` input and still exposes `set_slot_maintain_aspect_ratio(...)` for downstream repos that have not migrated yet. The seam is intentionally narrow:

- canonical storage/result/state fields are `fit_mode`
- legacy `maintain_aspect_ratio` is derived as `fit_mode != "stretch"`
- `contain` has no exact legacy boolean equivalent, so old callers can only faithfully express `stretch` vs `cover`

## Hidden `.testbed/` proving surface

The repo includes a hidden proving scene at:

- `.testbed/scenes/image_loader_testbed.tscn`

It provides:

- filesystem file picker flow for local `.png`
- one-click proof buttons for packaged `res://`, `user://`, and absolute-path loading
- two attached preview slots (`background` and `card`) driven through `AeroImageLoader`
- stretch / contain / cover toggling through the public singleton

## GodotEnv development flow

This repo uses the AeroBeat GodotEnv package convention.

- Canonical dev/test manifest: `.testbed/addons.jsonc`
- Installed dev/test addons: `.testbed/addons/`
- GodotEnv cache: `.testbed/.addons/`
- Hidden workbench project: `.testbed/project.godot`
- Repo-local unit tests: `.testbed/tests/`

The repo root remains the package/published boundary for downstream consumers. Day-to-day development, debugging, and validation happen from the hidden `.testbed/` workbench using the pinned OpenClaw toolchain: Godot `4.6.2 stable standard`.

### Restore dev/test dependencies

From the repo root:

```bash
cd .testbed
godotenv addons install
```

### Open the workbench

From the repo root:

```bash
godot --editor --path .testbed
```

Use this `.testbed/` project as the canonical direct-development and bugfinding surface for image-loader work.

### Import smoke check

From the repo root:

```bash
godot --headless --path .testbed --import
```

### Run unit tests

From the repo root:

```bash
godot --headless --path .testbed --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit
```
