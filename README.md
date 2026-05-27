# AeroBeat Image Loader

This repo now hosts the first **vendor-agnostic image-loading singleton** for the AeroBeat tool lane.

`AeroImageLoader` stays consumer-facing and backend-neutral: callers talk in terms of image paths, slot names, and whether a slot should maintain aspect ratio or stretch. The current truthful implementation resolves the landed `aerobeat-vendor-godot-image` backend at runtime and uses it as the thin PNG-loading/runtime surface.

## Current contract scope

- `src/AeroImageLoader.gd`
  - singleton/autoload-friendly public image-loading service
  - vendor-factory resolution at runtime through the installed `AeroGodotImageVendorFactory` global class
  - slot-aware surface attachment via `attach_slot_surface(slot_name, texture_rect, maintain_aspect_ratio := true)`
  - vendor-agnostic load requests via `load_image({...})` or `load_path(...)`
  - maintain-aspect (`cover`) vs stretch mapping owned here rather than exposed to consumers as vendor fit-mode vocabulary
- `assets/images/demo_tool_landscape.png`
  - checked-in PNG sample used by the hidden proving surface and automated tests
- hidden `.testbed/`
  - autoload wiring for `AeroImageLoader`
  - file-picker/manual proving scene that exercises slot placement + maintain-aspect/stretch through the public singleton only
  - repo-local GUT tests covering the wrapper contract against the real vendor backend

## Public surface

Example:

```gdscript
AeroImageLoader.attach_slot_surface("background", $BackgroundTextureRect, true)

var result := AeroImageLoader.load_image({
	"path": "res://addons/aerobeat-tool-image-loader/assets/images/demo_tool_landscape.png",
	"slot": "background",
	"maintain_aspect_ratio": true,
	"metadata": {"usage": "environment_background"},
})

if not result.get("success", false):
	push_error(result.get("message", "Image load failed"))
```

The public wrapper intentionally keeps vendor fit-mode terms out of the normal call site. Consumers choose:

- which **slot** should receive the image
- whether the slot should **maintain aspect ratio** or **stretch**
- a concrete local path (`res://`, `user://`, project-relative, or absolute device path)

## Hidden `.testbed/` proving surface

The repo includes a hidden proving scene at:

- `.testbed/scenes/image_loader_testbed.tscn`

It provides:

- filesystem file picker flow for local `.png`
- one-click proof buttons for packaged `res://`, `user://`, and absolute-path loading
- two attached preview slots (`background` and `card`) driven through `AeroImageLoader`
- maintain-aspect vs stretch toggling through the public singleton

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
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit
```
