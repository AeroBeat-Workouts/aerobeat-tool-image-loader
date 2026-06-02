# AeroBeat Tool Image Loader Testbed Asset Move

**Date:** 2026-05-28  
**Status:** Complete  
**Last Updated:** 2026-05-28 10:36 EDT  
**Blocked Reason:** None  
**Agent:** `cookie`

---

## Goal

Move the repo-root `assets/` folder for `aerobeat-tool-image-loader` into `/.testbed/` and repair the repo-owned testbed links and path references that break because of that move.

---

## Overview

This work belongs to `aerobeat-tool-image-loader`, so the coordination plan lives in that repo’s `/.plans/` folder. The current testbed script and regression tests were still pointing at `res://addons/aerobeat-tool-image-loader/assets/...`, which reflected the old repo-root asset layout mounted through the self-dependency. Once the sample asset moved into `/.testbed/assets/`, those proving-surface references needed to become testbed-local instead of addon-mounted.

Derrick explicitly asked for the implementation pass only and would handle manual QA/audit afterwards. This slice therefore covered only the coder pass: move the repo-owned assets into `/.testbed/`, update the repo-owned `.testbed` scripts/tests/import metadata/path helpers, run repo-local validation, commit/push, and hand the result back for Derrick’s manual verification.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Owning repo root | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader` |
| `REF-02` | Testbed controller script | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader/.testbed/scripts/image_loader_testbed.gd` |
| `REF-03` | Testbed regression coverage | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader/.testbed/tests/test_AeroImageLoader.gd` |
| `REF-04` | Current repo-root asset location to move | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader/assets/` |
| `REF-05` | Target hidden testbed asset location | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader/.testbed/assets/` |

---

## Tasks

### Task 1: Move repo-owned assets into `.testbed` and repair testbed references

**Bead ID:** `aerobeat-tool-image-loader-2xs`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Claim the assigned bead with `bd update <id> --status in_progress --json` at start. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader`, move the repo-root `assets/` folder into `/.testbed/`, then repair the repo-owned `.testbed` scripts/tests/import metadata/path references that still assume the old addon-mounted repo-root asset location. Update only the real owning source files, not generated addon copies. Run relevant repo-local validation, commit/push to `main` by default, and leave a precise handoff with root cause, files changed, validation, and commit hash. Derrick will handle manual QA/audit after the fix lands.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader/assets/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader/.testbed/`

**Files Created/Deleted/Modified:**
- `README.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader/.testbed/scripts/image_loader_testbed.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader/.testbed/tests/test_AeroImageLoader.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader/.testbed/assets/images/demo_tool_landscape.png`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-image-loader/.testbed/assets/images/demo_tool_landscape.png.import`

**Status:** ✅ Complete

**Results:** The root cause was that the demo PNG was still living at repo root as if it were addon-packaged content, while its actual consumers were the hidden `.testbed` scene/tests. After the move, the repo-owned testbed scripts/tests and the `.import` metadata still pointed at the old addon-mounted path. The fix moved the sample PNG and its `.import` file into `.testbed/assets/images/`, rewired testbed sample constants from `res://addons/aerobeat-tool-image-loader/assets/images/...` to `res://assets/images/...`, fixed the missing-file regression path to the new testbed asset surface, and updated the README so docs match the new sample location. Repo-local validation passed: `godot --headless --path .testbed --import` and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` completed with `5/5 tests passed`. The fix was committed and pushed in `20944ee` (`Move image-loader sample assets into testbed`).

---

### Task 2: QA the moved-asset repro

**Bead ID:** `Skipped by user`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-02`, `REF-03`, `REF-05`  
**Prompt:** Skipped by Derrick for this execution pass; Derrick will manually verify the moved-asset testbed behavior.

**Folders Created/Deleted/Modified:**
- None for this execution pass

**Files Created/Deleted/Modified:**
- None for this execution pass

**Status:** ⏭️ Skipped by user

**Results:** Derrick explicitly asked to handle QA manually.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Moved the tool-image-loader sample asset into the hidden `.testbed/assets/` workbench surface and repaired the repo-owned testbed scripts, tests, docs, and import metadata so they now target the testbed-local asset path instead of the old addon-mounted repo-root path.

**Reference Check:** `REF-01` through `REF-05` were satisfied for the implementation slice. Manual QA/audit were intentionally deferred to Derrick by request.

**Commits:**
- `20944ee` — `Move image-loader sample assets into testbed`

**Lessons Learned:** When a testbed consumes its own repo as a self-dependency, moving sample assets from repo root into `/.testbed/` flips proving-surface paths from addon-mounted references to testbed-local `res://assets/...` references, and the `.import` metadata needs to move with the asset.

---

*Completed on 2026-05-28*
