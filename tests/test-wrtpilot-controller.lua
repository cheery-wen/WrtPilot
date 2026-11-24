-- WrtPilot controller regression tests.
--
-- Run from the repository root:
--   lua5.1 tests/test-wrtpilot-controller.lua
--
-- Loads the real controller with stubbed LuCI modules. No network access,
-- no firmware download and no sysupgrade is ever executed: every shell
-- invocation is intercepted by the sys.call/sys.exec stubs.

local script_path = arg[1]
    or "luci-app-wrtpilot/luasrc/controller/wrtpilot.lua"

local stub = {
    form = {},
    responses = {},
    sys_calls = {},
    sys_execs = {},
    call_map = {},
    exec_map = {},
    json_map = {},
    fs_files = {},
    fs_stats = {},
    uci_options = {},
    uci_section = true,
    uci_fail_commit = false
}

local function reset()
    stub.form = {}
    stub.responses = {}
    stub.sys_calls = {}
    stub.sys_execs = {}
    stub.call_map = {}
    stub.exec_map = {}
    stub.json_map = {}
    stub.fs_files = {}
    stub.fs_stats = {}
    stub.uci_options = {}
    stub.uci_section = true
    stub.uci_fail_commit = false
end

local function last_response()
    return stub.responses[#stub.responses]
end

local function count_calls(list, needle)
    local n = 0
    for _, cmd in ipairs(list) do
        if cmd:find(needle, 1, true) then
            n = n + 1
        end
    end
    return n
end

-- ── LuCI module stubs ──────────────────────────────────────────────

local http = {}
function http.formvalue(key)
    return stub.form[key]
end
function http.prepare_content(_) end
function http.write_json(tbl)
    stub.responses[#stub.responses + 1] = tbl
end
function http.status(_, _) end
function http.header(_, _) end
function http.write(_) end

local uci = {}
function uci:get(_, _, option)
    if option == nil then
        return stub.uci_section and "wrtpilot" or nil
    end
    return stub.uci_options[option]
end
function uci:set(_, _, option, value)
    stub.uci_options[option] = value
    return true
end
function uci:delete(_, _, option)
    stub.uci_options[option] = nil
    return true
end
function uci:commit(_)
    return not stub.uci_fail_commit
end
function uci:section(_, _, _, _)
    stub.uci_section = true
    return true
end

local sys = {}
local LOCK_DIR = "/tmp/wrtpilot-task.lock"
function sys.call(cmd)
    stub.sys_calls[#stub.sys_calls + 1] = cmd
    for needle, rc in pairs(stub.call_map) do
        if cmd:find(needle, 1, true) then
            return rc
        end
    end
    -- Emulate real filesystem semantics for the lock primitives so the
    -- stale-lock tests exercise genuine mkdir/rmdir behaviour.
    if cmd:find(LOCK_DIR, 1, true)
        and (cmd:find("mkdir", 1, true) == 1
            or cmd:find("mv ", 1, true) == 1
            or cmd:find("rmdir", 1, true) == 1
            or cmd:find("rm -f", 1, true) == 1
            or cmd:find("rm -rf", 1, true) == 1) then
        return os.execute(cmd) == 0 and 0 or 1
    end
    return 0
end
function sys.exec(cmd)
    stub.sys_execs[#stub.sys_execs + 1] = cmd
    for needle, output in pairs(stub.exec_map) do
        if cmd:find(needle, 1, true) then
            return output
        end
    end
    return ""
end

local fs = {}
function fs.access(path)
    return stub.fs_files[path] and true or false
end
function fs.stat(path)
    return stub.fs_stats[path]
end
function fs.unlink(path)
    stub.fs_files[path] = nil
    stub.fs_stats[path] = nil
end

local util = {}
function util.shellquote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local jsonc = {}
function jsonc.parse(raw)
    return stub.json_map[raw]
end

local i18n = { translate = function(s) return s end }

package.preload["luci.http"] = function() return http end
package.preload["luci.jsonc"] = function() return jsonc end
package.preload["luci.i18n"] = function() return i18n end
package.preload["luci.model.uci"] = function()
    return { cursor = function() return uci end }
end
package.preload["nixio.fs"] = function() return fs end
package.preload["luci.sys"] = function() return sys end
package.preload["luci.util"] = function() return util end
package.preload["nixio"] = function()
    return { getpid = function() return 4242 end }
end

assert(loadfile(script_path), "Unable to load controller: " .. script_path)()

local ctrl = package.loaded["luci.controller.wrtpilot"]
assert(type(ctrl) == "table", "Controller module did not load")

-- The cron sync path writes the real crontab file; make sure its directory
-- exists (CI prepares it with sudo, local root runs can create it directly).
os.execute("mkdir -p /etc/crontabs 2>/dev/null")

local passed = 0
local function check(name, condition)
    assert(condition, "FAIL: " .. name)
    passed = passed + 1
    io.write("PASS: ", name, "\n")
end

local HASH = string.rep("a", 64)
local PREV_CACHE = "/tmp/wrtpilot-prev-release-v2.cache"

local function cleanup_real_files()
    os.execute("rm -rf " .. LOCK_DIR)
    os.remove(PREV_CACHE)
    os.remove("/tmp/wrtpilot_tddfw.bin.sha256.ok")
end

-- ── Automatic-upgrade time preservation ────────────────────────────

reset()
cleanup_real_files()
stub.uci_options.auto_upgrade_enabled = "0"
stub.uci_options.auto_upgrade_time = "07:30"
stub.form = { valid_extensions = ".img .bin" }
ctrl.action_config()
check(
    "extension-only save keeps the stored automatic upgrade time",
    stub.uci_options.auto_upgrade_time == "07:30"
)
check(
    "extension-only save succeeds",
    last_response() and last_response().ok == true
)

reset()
stub.uci_options.auto_upgrade_enabled = "1"
stub.uci_options.auto_upgrade_time = "07:30"
stub.form = {
    auto_upgrade_enabled = "0",
    auto_upgrade_time = "07:30"
}
ctrl.action_config()
check(
    "explicitly disabling automatic upgrade clears the stored time",
    stub.uci_options.auto_upgrade_time == ""
)

-- ── keep_config value normalization ────────────────────────────────

reset()
stub.uci_options.keep_config = "1"
stub.form = { keep_config = "banana" }
ctrl.action_config()
check(
    "invalid keep_config input is rejected",
    last_response() and last_response().ok == false
)
check(
    "invalid keep_config input does not overwrite the stored value",
    stub.uci_options.keep_config == "1"
)

reset()
stub.form = { keep_config = "1" }
ctrl.action_config()
check(
    "keep_config value 1 is preserved",
    stub.uci_options.keep_config == "1"
)

-- ── Upgrade launch failure rolls back keep_config ──────────────────

reset()
cleanup_real_files()
stub.uci_options.selected_release = "old-firmware.bin"
stub.uci_options.keep_config = "1"
stub.fs_files["/tmp/wrtpilot_tddfw.bin"] = true
stub.exec_map["sha256sum"] = HASH .. "\n"
stub.call_map["wrtpilot-upgrade.log"] = 1
local marker = assert(io.open("/tmp/wrtpilot_tddfw.bin.sha256.ok", "w"))
marker:write(HASH, "\n")
marker:close()
stub.form = { fw_name = "tddfw.bin", keep_config = "0" }
ctrl.action_upgrade()
check(
    "upgrade launch failure is reported",
    last_response() and last_response().ok == false
)
check(
    "upgrade launch failure restores the previous selected_release",
    stub.uci_options.selected_release == "old-firmware.bin"
)
check(
    "upgrade launch failure restores the previous keep_config",
    stub.uci_options.keep_config == "1"
)
check(
    "manual upgrade uses a real background PID and owner-checked lock cleanup",
    count_calls(stub.sys_calls, "owner_pid=$$") >= 1
        and count_calls(stub.sys_calls, "cat '" .. LOCK_DIR .. "/pid") >= 1
)
cleanup_real_files()

-- ── Download rejects assets without a SHA256 digest up front ───────

reset()
cleanup_real_files()
stub.form = {
    selected_release = "v2026.11.24",
    asset_url = "https://github.com/cheery-wen/OpenWrt/releases/download/v1/firmware.bin",
    asset_name = "firmware.bin",
    asset_size = "1024",
    asset_digest = ""
}
ctrl.action_download()
check(
    "download without a SHA256 digest is rejected before starting",
    last_response() and last_response().ok == false
)
check(
    "rejected digest-less download does not acquire the task lock",
    count_calls(stub.sys_calls, "mkdir") == 0
)

-- ── Stale task lock recovery ───────────────────────────────────────

local function write_lock_pid(pid)
    os.execute("mkdir -p " .. LOCK_DIR)
    local f = assert(io.open(LOCK_DIR .. "/pid", "w"))
    f:write(tostring(pid), "\n")
    f:close()
end

local function valid_download_form()
    return {
        selected_release = "v2026.11.24",
        asset_url = "https://github.com/cheery-wen/OpenWrt/releases/download/v1/firmware.bin",
        asset_name = "firmware.bin",
        asset_size = "1024",
        asset_digest = HASH
    }
end

reset()
cleanup_real_files()
write_lock_pid(999999)
stub.call_map["kill -0 999999"] = 1 -- recorded owner is dead
stub.fs_stats[LOCK_DIR] = { mtime = os.time() - 3600 }
stub.form = valid_download_form()
ctrl.action_download()
check(
    "a lock whose recorded owner is dead is reclaimed",
    last_response() and last_response().ok == true
)
check(
    "stale lock reclamation uses an atomic directory rename",
    count_calls(stub.sys_calls, "mv ") >= 1
)
check(
    "manual download records the background shell PID and checks lock ownership on exit",
    count_calls(stub.sys_calls, "owner_pid=$$") >= 1
        and count_calls(stub.sys_calls, "cat '" .. LOCK_DIR .. "/pid") >= 1
)
cleanup_real_files()

reset()
cleanup_real_files()
write_lock_pid(999999)
stub.call_map["kill -0 999999"] = 0 -- recorded owner is alive
stub.form = valid_download_form()
ctrl.action_download()
check(
    "a lock whose recorded owner is alive still blocks new tasks",
    last_response() and last_response().ok == false
)
cleanup_real_files()

reset()
cleanup_real_files()
os.execute("mkdir -p " .. LOCK_DIR) -- lock exists, no PID recorded yet
stub.fs_stats[LOCK_DIR] = { mtime = os.time() } -- just created
stub.form = valid_download_form()
ctrl.action_download()
check(
    "a freshly created lock without a PID is respected during the grace period",
    last_response() and last_response().ok == false
)
cleanup_real_files()

reset()
cleanup_real_files()
os.execute("mkdir -p " .. LOCK_DIR) -- abandoned lock, no PID, old
stub.fs_stats[LOCK_DIR] = { mtime = os.time() - 3600 }
stub.form = valid_download_form()
ctrl.action_download()
check(
    "an old lock without a PID is reclaimed",
    last_response() and last_response().ok == true
)
cleanup_real_files()

-- ── Previous-release cache reduces GitHub API calls ────────────────

reset()
cleanup_real_files()
stub.json_map["LATEST"] = {
    tag_name = "v2",
    name = "v2",
    published_at = "2026-11-23T00:00:00Z",
    html_url = "https://github.com/cheery-wen/OpenWrt/releases/tag/v2",
    assets = {
        {
            name = "firmware.img.gz",
            browser_download_url = "https://github.com/cheery-wen/OpenWrt/releases/download/v2/firmware.img.gz",
            size = 1024,
            digest = "sha256:" .. HASH
        }
    }
}
stub.json_map["LIST"] = {
    {
        tag_name = "v1",
        name = "v1",
        assets = {
            { name = "a.img", browser_download_url = "u1", size = 1 },
            { name = "b.img", browser_download_url = "u2", size = 1 },
            { name = "c.img", browser_download_url = "u3", size = 1 }
        }
    }
}
stub.exec_map["releases/latest"] = "LATEST"
stub.exec_map["releases?per_page=10"] = "LIST"
stub.form = { fetch_timeout = "15" }
ctrl.action_status()
check("first status refresh succeeds", last_response() and last_response().ok == true)
ctrl.action_status()
check("second status refresh succeeds", last_response() and last_response().ok == true)
check(
    "repeated status refresh reuses the cached previous-release asset count",
    count_calls(stub.sys_execs, "releases?per_page=10") == 1
)
check(
    "partial-assets hint still works from the cached count",
    last_response().partial_assets == true
)
cleanup_real_files()

-- A transient previous-release API failure must not be cached as zero assets.
reset()
cleanup_real_files()
stub.json_map["LATEST_TRANSIENT"] = {
    tag_name = "v3",
    name = "v3",
    published_at = "2026-11-24T00:00:00Z",
    html_url = "https://github.com/cheery-wen/OpenWrt/releases/tag/v3",
    assets = {
        {
            name = "firmware.img.gz",
            browser_download_url = "https://github.com/cheery-wen/OpenWrt/releases/download/v3/firmware.img.gz",
            size = 1024,
            digest = "sha256:" .. HASH
        }
    }
}
stub.exec_map["releases/latest"] = "LATEST_TRANSIENT"
stub.form = { fetch_timeout = "15" }
ctrl.action_status()
ctrl.action_status()
local cache_file = io.open(PREV_CACHE, "r")
check(
    "failed previous-release API lookups are not cached as zero assets",
    cache_file == nil
)
if cache_file then cache_file:close() end
check(
    "transient previous-release API failures are retried on the next refresh",
    count_calls(stub.sys_execs, "releases?per_page=10") >= 4
)
cleanup_real_files()

io.write("\nAll ", passed, " WrtPilot controller tests passed.\n")
