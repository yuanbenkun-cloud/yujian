extends RefCounted
## Windows DPAPI CurrentUser. Secrets travel through stdin, never command arguments.
const CONFIG: String = "user://yudeng_ai.cfg"

static func _crypt(value: String, decrypt: bool = false) -> String:
	if OS.get_name() != "Windows" or value.is_empty(): return ""
	var operation: String = "Unprotect" if decrypt else "Protect"
	var command: String = "$ErrorActionPreference='Stop'; try { Add-Type -AssemblyName System.Security; $s=[Console]::ReadLine(); $b=[Convert]::FromBase64String($s); $r=[Security.Cryptography.ProtectedData]::%s($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser); [Console]::WriteLine([Convert]::ToBase64String($r)) } catch { [Console]::WriteLine('FAILED') }" % operation
	var process: Dictionary = OS.execute_with_pipe("powershell.exe", PackedStringArray(["-NoLogo", "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-Command", command]), true)
	var pipe: FileAccess = process.get("stdio")
	if pipe == null: return ""
	# Both directions use base64 solely as transport encoding; DPAPI supplies encryption.
	pipe.store_line(value if decrypt else Marshalls.utf8_to_base64(value))
	var result: String = pipe.get_line().strip_edges()
	pipe.close()
	if result.is_empty() or result == "FAILED": return ""
	return Marshalls.base64_to_utf8(result) if decrypt else result

static func save_key(value: String, path: String = CONFIG, endpoint: String = "https://open.bigmodel.cn/api/paas/v4/chat/completions", model: String = "glm-4.7-flash") -> bool:
	var protected: String = _crypt(JSON.stringify({"api_key": value, "endpoint": endpoint}))
	if protected.is_empty(): return false
	var cfg := ConfigFile.new()
	cfg.set_value("zhipu", "dpapi_current_user", protected)
	cfg.set_value("connection", "endpoint", endpoint)
	cfg.set_value("connection", "model", model)
	return cfg.save(path) == OK

static func load_key(path: String = CONFIG) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK: return ""
	if cfg.has_section_key("zhipu", "dpapi_current_user"):
		var decoded: String = _crypt(str(cfg.get_value("zhipu", "dpapi_current_user")), true)
		var parser := JSON.new()
		var payload: Variant = parser.data if parser.parse(decoded) == OK else null
		var endpoint: String = str(cfg.get_value("connection", "endpoint", "https://open.bigmodel.cn/api/paas/v4/chat/completions"))
		if payload is Dictionary:
			return str(payload.get("api_key", "")) if payload.get("endpoint", "") == endpoint else ""
		# Earlier encrypted keys were Zhipu-only; do not reuse them for a new host.
		if endpoint == "https://open.bigmodel.cn/api/paas/v4/chat/completions" and not decoded.is_empty():
			save_key(decoded, path)
			return decoded
		return ""
	# Migrate the developer's existing local-only plaintext config in place.
	var legacy: String = str(cfg.get_value("zhipu", "api_key", "")).strip_edges()
	if not legacy.is_empty(): save_key(legacy, path)
	return legacy

static func delete_key(path: String = CONFIG) -> bool:
	if not FileAccess.file_exists(path): return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
