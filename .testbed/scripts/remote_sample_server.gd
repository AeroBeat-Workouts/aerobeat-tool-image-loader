class_name RemoteSampleServer
extends RefCounted

const SERVER_SCRIPT_PATH := "res://scripts/remote_png_fixture_server.py"
const PORT_FILE_PREFIX := "aerobeat-remote-png-port-"

var _pid: int = -1
var _port_file_path: String = ""

func start(root_path: String, sample_file_name: String) -> Dictionary:
	stop()
	var absolute_root := ProjectSettings.globalize_path(root_path)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return {
			"success": false,
			"message": "Remote sample root directory does not exist.",
			"detail": {"root_path": root_path, "absolute_root": absolute_root},
		}
	var server_script := ProjectSettings.globalize_path(SERVER_SCRIPT_PATH)
	if not FileAccess.file_exists(server_script):
		return {
			"success": false,
			"message": "Remote sample server script is missing.",
			"detail": {"server_script": server_script},
		}

	_port_file_path = OS.get_cache_dir().path_join("%s%s.txt" % [PORT_FILE_PREFIX, str(Time.get_unix_time_from_system())])
	if FileAccess.file_exists(_port_file_path):
		DirAccess.remove_absolute(_port_file_path)
	var pid := OS.create_process("python3", [server_script, "--root", absolute_root, "--port-file", _port_file_path], false)
	if pid <= 0:
		_port_file_path = ""
		return {
			"success": false,
			"message": "Could not start python3 fixture server.",
			"detail": {"server_script": server_script},
		}
	_pid = pid

	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(_port_file_path):
			var port_file := FileAccess.open(_port_file_path, FileAccess.READ)
			if port_file != null:
				var port_text := port_file.get_as_text().strip_edges()
				var port := int(port_text)
				if port > 0:
					return {
						"success": true,
						"detail": {
							"pid": _pid,
							"port": port,
							"url": "http://127.0.0.1:%s/%s" % [str(port), sample_file_name.uri_encode()],
						},
					}
		OS.delay_msec(50)

	stop()
	return {
		"success": false,
		"message": "Timed out waiting for the remote sample fixture server.",
		"detail": {"root_path": root_path, "port_file_path": _port_file_path},
	}

func stop() -> void:
	if _pid > 0:
		OS.kill(_pid)
		OS.delay_msec(25)
	_pid = -1
	if not _port_file_path.is_empty() and FileAccess.file_exists(_port_file_path):
		DirAccess.remove_absolute(_port_file_path)
	_port_file_path = ""
