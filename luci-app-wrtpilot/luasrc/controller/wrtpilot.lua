
-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 cheery-wen
-- Repository: https://github.com/cheery-wen/WrtPilot

module("luci.controller.wrtpilot", package.seeall)

local http = require "luci.http"
local jsonc = require "luci.jsonc"
local i18n = require "luci.i18n"
local uci = require("luci.model.uci").cursor()
local fs = require "nixio.fs"
local sys = require "luci.sys"
local util = require "luci.util"

local CFG = "wrtpilot"
local SEC = "main"
local tr = i18n.translate

local AUTO_UPGRADE_COMMAND = "lua /usr/libexec/wrtpilot-auto-upgrade"
local AUTO_UPGRADE_CRONTAB = "/etc/crontabs/root"

local function json_resp(tbl)
    http.prepare_content("application/json")
    http.write_json(tbl)
end

local function to_bool(v)
    return v == "1" or v == "true" or v == "on" or v == "yes"
end

local function trim(s)
    if not s then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function read_lines(path)
    local f = io.open(path, "r")
    if not f then
        return {}
    end

    local lines = {}
    for line in f:lines() do
        lines[#lines + 1] = line
    end
    f:close()
    return lines
end

local function human_bytes(n)
    n = tonumber(n) or 0
    if n < 0 then
        n = 0
    end
    local units = { "B", "KB", "MB", "GB", "TB" }
    local idx = 1
    while n >= 1024 and idx < #units do
        n = n / 1024
        idx = idx + 1
    end

    if idx == 1 then
        return string.format("%d %s", math.floor(n + 0.5), units[idx])
    end

    return string.format("%.2f %s", n, units[idx])
end

local DEFAULT_VALID_EXTS = ".img .img.gz .bin .tar .itb .trx .chk .dlf .ari"

local function validate_auto_upgrade_time(value)
    value = trim(value)

    local hour, minute = value:match("^(%d%d):(%d%d)$")
    hour = tonumber(hour)
    minute = tonumber(minute)

    if not hour or not minute or hour < 0 or hour > 23
        or minute < 0 or minute > 59 then
        return nil
    end

    return string.format("%02d:%02d", hour, minute)
end

local function is_wrtpilot_auto_upgrade_cron(line)
    line = trim(line)

    return line:match("lua /usr/libexec/wrtpilot%-auto%-upgrade$") ~= nil
end

local function sync_auto_upgrade_cron(enabled, upgrade_time)
    local lines = read_lines(AUTO_UPGRADE_CRONTAB)
    local new_lines = {}

    -- Remove only WrtPilot automatic-upgrade entries.
    -- Other system and user cron jobs are preserved.
    for _, line in ipairs(lines) do
        if not is_wrtpilot_auto_upgrade_cron(line) then
            new_lines[#new_lines + 1] = line
        end
    end

    if enabled == "1" then
        local valid_time = validate_auto_upgrade_time(upgrade_time)
        if not valid_time then
            return false, tr("Please select a valid automatic upgrade time")
        end

        local hour, minute = valid_time:match("^(%d%d):(%d%d)$")

        new_lines[#new_lines + 1] =
            string.format("%s %s * * * %s", tonumber(minute), tonumber(hour), AUTO_UPGRADE_COMMAND)
    end

    local temp_path = AUTO_UPGRADE_CRONTAB .. ".wrtpilot.tmp"
    local file = io.open(temp_path, "w")

    if not file then
        return false, tr("Unable to write the automatic upgrade schedule")
    end

    for _, line in ipairs(new_lines) do
        file:write(line, "\n")
    end

    file:close()

    if not os.rename(temp_path, AUTO_UPGRADE_CRONTAB) then
        os.remove(temp_path)
        return false, tr("Unable to update the automatic upgrade schedule")
    end

    -- Reload cron so the changed schedule takes effect.
    sys.call("/etc/init.d/cron restart >/dev/null 2>&1")

    return true
end

local function migrate_legacy_filter_cfg()
    if not uci:get(CFG, SEC) then
        return
    end

    local changed = false

    if uci:get(CFG, SEC, "filter_ext_enabled") == nil then
        uci:set(CFG, SEC, "filter_ext_enabled", "1")
        changed = true
    end

    local valid_extensions = uci:get(CFG, SEC, "valid_extensions")
    if not valid_extensions or trim(valid_extensions) == "" then
        uci:set(CFG, SEC, "valid_extensions", DEFAULT_VALID_EXTS)
        changed = true
    end

    if uci:get(CFG, SEC, "filter_prefix_enabled") ~= nil then
        uci:delete(CFG, SEC, "filter_prefix_enabled")
        changed = true
    end
    if uci:get(CFG, SEC, "filter_prefix") ~= nil then
        uci:delete(CFG, SEC, "filter_prefix")
        changed = true
    end
    if uci:get(CFG, SEC, "filter_min_size_enabled") ~= nil then
        uci:delete(CFG, SEC, "filter_min_size_enabled")
        changed = true
    end
    if uci:get(CFG, SEC, "filter_min_size") ~= nil then
        uci:delete(CFG, SEC, "filter_min_size")
        changed = true
    end

    if changed then
        uci:commit(CFG)
    end
end

local function get_cfg()
    migrate_legacy_filter_cfg()

    return {
        selected_release = uci:get(CFG, SEC, "selected_release") or "",
        keep_config = uci:get(CFG, SEC, "keep_config") or "1",
        fetch_timeout = uci:get(CFG, SEC, "fetch_timeout") or "15",
        filter_ext_enabled = uci:get(CFG, SEC, "filter_ext_enabled") or "1",
        valid_extensions = uci:get(CFG, SEC, "valid_extensions") or DEFAULT_VALID_EXTS,
        auto_upgrade_enabled = uci:get(CFG, SEC, "auto_upgrade_enabled") or "0",
        auto_upgrade_time = uci:get(CFG, SEC, "auto_upgrade_time") or ""
    }
end

local function set_cfg(
    selected_release,
    keep_config,
    fetch_timeout,
    filter_ext_enabled,
    valid_extensions,
    auto_upgrade_enabled,
    auto_upgrade_time
)
    if not uci:get(CFG, SEC) then
        uci:section(CFG, "wrtpilot", SEC, {})
    end

    if selected_release ~= nil then
        uci:set(CFG, SEC, "selected_release", selected_release)
    end

    if keep_config ~= nil then
        uci:set(CFG, SEC, "keep_config", keep_config)
    end

    if fetch_timeout ~= nil then
        local t = tonumber(fetch_timeout)
        if t and t >= 5 and t <= 300 then
            uci:set(CFG, SEC, "fetch_timeout", tostring(math.floor(t)))
        end
    end

    if filter_ext_enabled ~= nil then
        uci:set(CFG, SEC, "filter_ext_enabled", to_bool(filter_ext_enabled) and "1" or "0")
    end

    if valid_extensions ~= nil then
        local v = trim(valid_extensions)
        v = v:gsub("[\r\n]+", " "):gsub("%s+", " ")
        uci:set(CFG, SEC, "valid_extensions", v)
    end

    if auto_upgrade_enabled ~= nil then
        uci:set(CFG, SEC, "auto_upgrade_enabled", auto_upgrade_enabled)
    end

    if auto_upgrade_time ~= nil then
        uci:set(CFG, SEC, "auto_upgrade_time", auto_upgrade_time)
    end

    uci:commit(CFG)
end

local function get_install_epoch()
    -- Prefer dedicated flash timestamp written by uci-defaults on every post-flash boot
    local f = io.open("/etc/wrtpilot_flash_epoch", "r")
    if f then
        local v = f:read("*l")
        f:close()
        local epoch = tonumber(v)
        if epoch and epoch > 0 then
            return epoch
        end
    end

    -- Fallback: mtime of /etc/openwrt_version
    local st = fs.stat("/etc/openwrt_version")
    if st and st.mtime then
        return tonumber(st.mtime) or 0
    end

    return 0
end

local function epoch_to_iso_utc(epoch)
    if not epoch or epoch <= 0 then
        return ""
    end
    return os.date("!%Y-%m-%dT%H:%M:%SZ", epoch)
end

local function epoch_to_local_string(epoch)
    if not epoch or epoch <= 0 then
        return ""
    end
    return os.date("%Y-%m-%d %H:%M:%S", epoch)
end

local function get_tz_offset_minutes()
    local z = os.date("%z") or "+0000"
    local sign, hh, mm = z:match("([%+%-])(%d%d)(%d%d)")
    if not sign then
        return 0
    end

    local v = (tonumber(hh) or 0) * 60 + (tonumber(mm) or 0)
    if sign == "-" then
        v = -v
    end
    return v
end

local function normalize_version(v)
    v = trim(v or "")
    if v == "" then
        return ""
    end

    v = v:gsub("^luci%-app%-wrtpilot[-%s]+", "")
    local token = v:match("([0-9][%w%.%+%-%_~]*)")
    return token or ""
end

local function read_first_line(path)
    local f = io.open(path, "r")
    if not f then
        return ""
    end
    local line = f:read("*l") or ""
    f:close()
    return trim(line)
end

local function read_apk_db_version(path)
    local f = io.open(path, "r")
    if not f then
        return ""
    end

    local found = false
    for line in f:lines() do
        if line == "P:luci-app-wrtpilot" then
            found = true
        elseif found and line:match("^V:") then
            f:close()
            return normalize_version(line:sub(3))
        elseif found and line == "" then
            found = false
        end
    end
    f:close()
    return ""
end

local function get_app_version()
    local apk_db_ver = read_apk_db_version("/lib/apk/db/installed")
    if apk_db_ver ~= "" then
        return apk_db_ver
    end

    apk_db_ver = read_apk_db_version("/usr/lib/apk/db/installed")
    if apk_db_ver ~= "" then
        return apk_db_ver
    end

    local opkg_ctrl_ver = normalize_version(sys.exec("sh -c \"awk -F': ' '/^Version:/{print $2; exit}' /usr/lib/opkg/info/luci-app-wrtpilot.control 2>/dev/null\""))
    if opkg_ctrl_ver ~= "" then
        return opkg_ctrl_ver
    end

    local opkg_status_ver = normalize_version(sys.exec("sh -c \"awk 'BEGIN{f=0} /^Package: luci-app-wrtpilot$/{f=1;next} f&&/^Version:/{sub(/^Version: /,\"\"); print; exit} f&&/^$/{f=0}' /usr/lib/opkg/status 2>/dev/null\""))
    if opkg_status_ver ~= "" then
        return opkg_status_ver
    end

    local apk_line_ver = normalize_version(sys.exec("sh -c \"apk info -v luci-app-wrtpilot 2>/dev/null | head -n1\""))
    if apk_line_ver ~= "" then
        return apk_line_ver
    end

    local opkg_ver = normalize_version(sys.exec("sh -c \"opkg status luci-app-wrtpilot 2>/dev/null | awk -F': ' '/^Version:/{print $2; exit}'\""))
    if opkg_ver ~= "" then
        return opkg_ver
    end

    local verfile = normalize_version(read_first_line("/usr/share/wrtpilot/version"))
    if verfile ~= "" then
        return verfile
    end

    return ""
end

local function parse_assets(raw_assets)
    local assets = {}
    if not raw_assets or type(raw_assets) ~= "table" then
        return assets
    end

    local tmp = {}
    for k, a in pairs(raw_assets) do
        if type(a) == "table" then
            local digest_raw = tostring(a.digest or "")
            local sha256_val = digest_raw:match("^sha256:([a-f0-9]+)$") or ""
            tmp[#tmp + 1] = {
                idx = tonumber(k) or (1000000 + #tmp),
                name = a.name or "",
                url = a.browser_download_url or "",
                size = a.size or 0,
                sha256 = sha256_val
            }
        end
    end

    table.sort(tmp, function(x, y)
        return (x.idx or 0) < (y.idx or 0)
    end)

    for _, a in ipairs(tmp) do
        assets[#assets + 1] = {
            name = a.name,
            url = a.url,
            size = a.size,
            sha256 = a.sha256
        }
    end

    return assets
end

local function release_from_obj(obj)
    return {
        tag_name = obj.tag_name or "",
        release_name = obj.name or obj.tag_name or "",
        published_at = obj.published_at or "",
        html_url = obj.html_url or "",
        assets = parse_assets(obj.assets)
    }
end

local fetch_github_json

local function fetch_previous_release_with_assets(repo, timeout, accept_header, exclude_tag)
    local releases_url = "https://api.github.com/repos/" .. repo .. "/releases?per_page=10"
    local rel_obj = fetch_github_json(releases_url, timeout, accept_header)
    if not rel_obj or type(rel_obj) ~= "table" then
        return nil
    end

    local rel_tmp = {}
    for k, v in pairs(rel_obj) do
        if type(v) == "table" then
            rel_tmp[#rel_tmp + 1] = {
                idx = tonumber(k) or (1000000 + #rel_tmp),
                item = v
            }
        end
    end

    table.sort(rel_tmp, function(x, y)
        return (x.idx or 0) < (y.idx or 0)
    end)

    for _, r in ipairs(rel_tmp) do
        local candidate = release_from_obj(r.item)
        if candidate.tag_name ~= "" and candidate.tag_name ~= exclude_tag and #candidate.assets > 0 then
            return candidate
        end
    end

    return nil
end

fetch_github_json = function(url, timeout, accept_header)
    local cmd = "wget -T " .. tostring(timeout) .. " --header=" .. util.shellquote(accept_header) .. " -qO- " .. util.shellquote(url) .. " 2>/dev/null"
    local raw = sys.exec(cmd)

    -- Fallback for wget variants without custom-header support.
    if not raw or raw == "" then
        local fallback = "wget -T " .. tostring(timeout) .. " -qO- " .. util.shellquote(url) .. " 2>/dev/null"
        raw = sys.exec(fallback)
    end

    if not raw or raw == "" then
        return nil, tr("Failed to fetch GitHub release data")
    end

    local obj = jsonc.parse(raw)
    if not obj then
        return nil, tr("Failed to parse GitHub API response")
    end

    return obj
end

local function fetch_latest_release(repo, timeout)
    local t = math.floor(tonumber(timeout) or 15)
    if t < 5 then t = 5 end
    if t > 300 then t = 300 end

    local accept = "Accept: application/vnd.github.full+json"
    local latest_url = "https://api.github.com/repos/" .. repo .. "/releases/latest"
    local obj, err = fetch_github_json(latest_url, t, accept)
    if not obj then
        return nil, err
    end

    if obj.message and not obj.tag_name then
        return nil, tr("GitHub API error: ") .. tostring(obj.message)
    end

    local latest = release_from_obj(obj)
    local info = {
        fallback_used = false,
        partial_assets = false
    }

    if #latest.assets > 0 then
        local prev = fetch_previous_release_with_assets(repo, t, accept, latest.tag_name)
        if prev and #prev.assets > #latest.assets then
            info.partial_assets = true
        end
        return latest, nil, info
    end

    -- Latest release exists but assets are not ready yet (e.g. CI still uploading).
    -- Fallback to the previous release that already has assets.
    local fallback = fetch_previous_release_with_assets(repo, t, accept, latest.tag_name)
    if fallback then
        info.fallback_used = true
        return fallback, nil, info
    end

    return latest, nil, info
end

function index()
    if not fs.access("/etc/config/wrtpilot") then
        return
    end

    entry({"admin", "system", "wrtpilot"}, call("action_index"), _("WrtPilot Firmware Upgrade"), 65)
    entry({"admin", "system", "wrtpilot", "status"}, call("action_status")).leaf = true
    entry({"admin", "system", "wrtpilot", "local_status"}, call("action_local_status")).leaf = true
    entry({"admin", "system", "wrtpilot", "config"}, call("action_config")).leaf = true
    entry({"admin", "system", "wrtpilot", "download"}, call("action_download")).leaf = true
    entry({"admin", "system", "wrtpilot", "download_status"}, call("action_download_status")).leaf = true
    entry({"admin", "system", "wrtpilot", "upgrade"}, call("action_upgrade")).leaf = true
    entry({"admin", "system", "wrtpilot", "backup"}, call("action_backup")).leaf = true
end

function action_index()
    luci.template.render("wrtpilot/main", {
        app_version = get_app_version()
    })
end

function action_local_status()
    local cfg = get_cfg()
    local app_version = get_app_version()
    local install_epoch = get_install_epoch()
    local install_local = epoch_to_local_string(install_epoch)

    json_resp({
        ok = true,
        app_version = app_version,
        config = cfg,
        install_epoch = install_epoch,
        install_time = install_local,
        tz_offset_min = get_tz_offset_minutes()
    })
end

function action_status()
    local cfg = get_cfg()
    local repo_input = "cheery-wen/OpenWrt"
    local app_version = get_app_version()

    -- Read and validate fetch_timeout from form; fall back to saved config
    local timeout_raw = trim(http.formvalue("fetch_timeout") or "")
    local fetch_timeout = tonumber(timeout_raw)
    if not fetch_timeout or fetch_timeout < 5 or fetch_timeout > 300 then
        fetch_timeout = tonumber(cfg.fetch_timeout) or 15
    end
    fetch_timeout = math.floor(fetch_timeout)

    -- Persist timeout setting
    set_cfg(nil, nil, tostring(fetch_timeout))

    local install_epoch = get_install_epoch()
    local install_iso = epoch_to_iso_utc(install_epoch)
    local install_local = epoch_to_local_string(install_epoch)

    local latest, err, rel_info = fetch_latest_release(repo_input, fetch_timeout)
    if not latest then
        local timed_out = (err == tr("Failed to fetch GitHub release data"))
        json_resp({
            ok = false,
            msg = timed_out and tr("Unable to fetch GitHub Release, please check your network connection") or err,
            app_version = app_version,
            config = cfg,
            install_epoch = install_epoch,
            install_time = install_local,
            tz_offset_min = get_tz_offset_minutes(),
            fetch_timeout = fetch_timeout
        })
        return
    end

    latest.release_total_count = (latest.assets and #latest.assets) or 0

    local has_new = false
    if latest.published_at ~= "" and install_iso ~= "" then
        has_new = latest.published_at > install_iso
    end

    local msg
    if has_new then
        msg = tr("New firmware is available")
    else
        msg = tr("No firmware newer than current system was found")
    end

    json_resp({
        ok = true,
        msg = msg,
        app_version = app_version,
        has_new = has_new,
        fallback_used = rel_info and rel_info.fallback_used or false,
        partial_assets = rel_info and rel_info.partial_assets or false,
        install_epoch = install_epoch,
        install_time = install_local,
        tz_offset_min = get_tz_offset_minutes(),
        fetch_timeout = fetch_timeout,
        config = get_cfg(),
        latest = latest
    })
end

function action_config()
    local keep_config = http.formvalue("keep_config")
    local fetch_timeout_raw = trim(http.formvalue("fetch_timeout") or "")
    local fetch_timeout = nil

    if fetch_timeout_raw ~= "" then
        local t = tonumber(fetch_timeout_raw)
        if t and t >= 5 and t <= 300 then
            fetch_timeout = tostring(math.floor(t))
        end
    end

    local filter_ext_enabled = http.formvalue("filter_ext_enabled")
    local valid_extensions = http.formvalue("valid_extensions")

    -- Read the existing automatic-upgrade settings.
    local current_enabled = uci:get(CFG, SEC, "auto_upgrade_enabled") or "0"
    local current_time = uci:get(CFG, SEC, "auto_upgrade_time") or ""

    local enabled_input = http.formvalue("auto_upgrade_enabled")
    local time_input = http.formvalue("auto_upgrade_time")

    local auto_upgrade_enabled = current_enabled
    local auto_upgrade_time = current_time

    if enabled_input ~= nil then
        if enabled_input ~= "0" and enabled_input ~= "1" then
            json_resp({
                ok = false,
                msg = tr("Invalid automatic upgrade setting")
            })
            return
        end

        auto_upgrade_enabled = enabled_input
    end

    if time_input ~= nil then
        auto_upgrade_time = trim(time_input)
    end

    if auto_upgrade_enabled == "1" then
        local valid_time = validate_auto_upgrade_time(auto_upgrade_time)

        if not valid_time then
            json_resp({
                ok = false,
                msg = tr("Please select a valid automatic upgrade time"),
                config = get_cfg()
            })
            return
        end

        auto_upgrade_time = valid_time
    else
        -- Disabled automatic upgrades do not retain an active schedule.
        if time_input == nil then
            auto_upgrade_time = ""
        end
    end

    set_cfg(
        nil,
        keep_config,
        fetch_timeout,
        filter_ext_enabled,
        valid_extensions,
        auto_upgrade_enabled,
        auto_upgrade_time
    )

    local cron_ok, cron_error = sync_auto_upgrade_cron(
        auto_upgrade_enabled,
        auto_upgrade_time
    )

    if not cron_ok then
        -- Fail closed if the schedule cannot be updated.
        set_cfg(nil, nil, nil, nil, nil, "0", "")
        sync_auto_upgrade_cron("0", "")

        json_resp({
            ok = false,
            msg = cron_error or tr("Unable to update the automatic upgrade schedule"),
            config = get_cfg()
        })
        return
    end

    json_resp({
        ok = true,
        config = get_cfg()
    })
end

function action_download()
    local selected_release = trim(http.formvalue("selected_release") or "")
    local keep_config = to_bool(http.formvalue("keep_config")) and "1" or "0"
    local cfg = get_cfg()
    local asset_url = trim(http.formvalue("asset_url") or "")
    local asset_name = trim(http.formvalue("asset_name") or "firmware.bin.gz")
    local asset_size = tonumber(trim(http.formvalue("asset_size") or "")) or 0
    local asset_digest = trim(http.formvalue("asset_digest") or "")

    if #asset_digest ~= 64 or not asset_digest:match("^[a-f0-9]+$") then
        asset_digest = ""
    end

    local logs = {}

    -- Do not replace the last successfully upgraded firmware while downloading.
    -- The selected asset is persisted only after the user confirms the upgrade
    -- and the backend verifies the downloaded file again in action_upgrade().
    set_cfg(nil, keep_config)

    if selected_release == "" then
        logs[#logs + 1] = tr("Please select firmware to upgrade")
        json_resp({ ok = false, logs = logs })
        return
    end

    if asset_url == "" then
        logs[#logs + 1] = tr("Please select a firmware asset")
        json_resp({ ok = false, logs = logs })
        return
    end

    if not asset_url:match("^https://github%.com/cheery%-wen/OpenWrt/releases/download/") then
        logs[#logs + 1] = tr("Invalid firmware URL, only https is supported")
        json_resp({ ok = false, logs = logs })
        return
    end

    local clean_name = asset_name:gsub("[^%w%._%-]", "_")
    if clean_name == "" then
        clean_name = "firmware.bin.gz"
    end

    local fw_path = "/tmp/wrtpilot_" .. clean_name
    local progress_log = "/tmp/wrtpilot-download-progress.log"
    local raw_log = "/tmp/wrtpilot-download-raw.log"
    local sha_marker = fw_path .. ".sha256.ok"
    fs.unlink(sha_marker)

    local download_timeout = math.floor(tonumber(cfg.fetch_timeout) or 15)
    if download_timeout < 120 then
        download_timeout = 120
    elseif download_timeout > 300 then
        download_timeout = 300
    end

    fs.unlink(progress_log)
    fs.unlink(raw_log)

    local shell_script = table.concat({
        "progress_log=", util.shellquote(progress_log), "\n",
        "raw_log=", util.shellquote(raw_log), "\n",
        "target=", util.shellquote(fw_path), "\n",
        "sha_marker=", util.shellquote(sha_marker), "\n",
        "total=", tostring(math.max(0, math.floor(asset_size))), "\n",
        "timeout=", tostring(download_timeout), "\n",
        "url=", util.shellquote(asset_url), "\n",
        ": > \"$progress_log\"\n",
        ": > \"$raw_log\"\n",
        "(\n",
        "if command -v wget >/dev/null 2>&1; then\n",
        "    wget -T \"$timeout\" -O \"$target\" \"$url\" >\"$raw_log\" 2>&1\n",
        "    rc=$?\n",
        "else\n",
        "    echo \"wget is not installed\" >\"$raw_log\"\n",
        "    rc=127\n",
        "fi\n",
        "exit \"$rc\"\n",
        ") &\n",
        "dlpid=$!\n",
        "prev_size=0\n",
        "prev_ts=$(date +%s)\n",
        "last_pct=-1\n",
        "while kill -0 \"$dlpid\" 2>/dev/null; do\n",
        "    sleep 1\n",
        "    size=$(wc -c < \"$target\" 2>/dev/null)\n",
        "    [ -z \"$size\" ] && size=0\n",
        "    now=$(date +%s)\n",
        "    elapsed=$((now - prev_ts))\n",
        "    [ \"$elapsed\" -le 0 ] && elapsed=1\n",
        "    delta=$((size - prev_size))\n",
        "    rate=$((delta / elapsed))\n",
        "    if [ \"$total\" -gt 0 ]; then\n",
        "        pct=$((size * 100 / total))\n",
        "        [ \"$pct\" -gt 100 ] && pct=100\n",
        "        if [ \"$pct\" -ne \"$last_pct\" ]; then\n",
        "            echo \"PROGRESS|$pct|$size|$total|$rate\" >> \"$progress_log\"\n",
        "            last_pct=$pct\n",
        "        fi\n",
        "    else\n",
        "        echo \"PROGRESS|0|$size|0|$rate\" >> \"$progress_log\"\n",
        "    fi\n",
        "    prev_size=$size\n",
        "    prev_ts=$now\n",
        "done\n",
        "wait \"$dlpid\"\n",
        "rc=$?\n",
        "size=$(wc -c < \"$target\" 2>/dev/null)\n",
        "[ -z \"$size\" ] && size=0\n",
        "if [ \"$rc\" -eq 0 ] && [ -s \"$target\" ]; then\n",
        "    sha256=$(sha256sum \"$target\" 2>/dev/null | awk '{print $1}')\n",
        "    expected=", util.shellquote(asset_digest), "\n",
        "    if [ -n \"$expected\" ] && [ -n \"$sha256\" ]; then\n",
        "        if [ \"$sha256\" = \"$expected\" ]; then\n",
        "            echo \"$sha256\" > \"$sha_marker\"\n",
        "            echo \"SHA256OK|$sha256\" >> \"$progress_log\"\n",
        "            echo \"DONE|OK|$size|$total|$target\" >> \"$progress_log\"\n",
        "        else\n",
        "            echo \"SHA256FAIL|$sha256|$expected\" >> \"$progress_log\"\n",
        "            echo \"DONE|FAIL|$size|$total|$target\" >> \"$progress_log\"\n",
        "            rm -f \"$target\" \"$sha_marker\"\n",
        "        fi\n",
        "    else\n",
        "        echo \"SHA256FAIL|$sha256|$expected\" >> \"$progress_log\"\n",
        "        echo \"DONE|FAIL|$size|$total|$target\" >> \"$progress_log\"\n",
        "        rm -f \"$target\" \"$sha_marker\"\n",
        "    fi\n",
        "else\n",
        "    echo \"DONE|FAIL|$size|$total|$target\" >> \"$progress_log\"\n",
        "    if [ -s \"$raw_log\" ]; then\n",
        "        sed 's/^/ERR|/' \"$raw_log\" >> \"$progress_log\"\n",
        "    fi\n",
        "fi\n",
    })

    logs[#logs + 1] = tr("Downloading firmware: ") .. clean_name
    local start_cmd = "sh -c " .. util.shellquote("(" .. shell_script .. ") >/dev/null 2>&1 &")
    local rc = sys.call(start_cmd)

    if rc ~= 0 then
        logs[#logs + 1] = tr("Firmware download failed, please check network or GitHub repository")
        json_resp({ ok = false, logs = logs })
        return
    end

    json_resp({
        ok = true,
        started = true,
        logs = logs
    })
end

function action_download_status()
    local offset = tonumber(trim(http.formvalue("offset") or "0")) or 0
    if offset < 0 then
        offset = 0
    end

    local progress_log = "/tmp/wrtpilot-download-progress.log"
    local lines = read_lines(progress_log)
    local total_lines = #lines

    local done = false
    local download_ok = false
    local sha256_fail = false
    local fw_name = ""

    for _, line in ipairs(lines) do
        local status, _, _, target = line:match("^DONE|([A-Z]+)|(%d+)|(%d+)|(.+)$")
        if status then
            done = true
            download_ok = (status == "OK")
            local n = tostring(target or ""):match("/tmp/wrtpilot_(.+)$")
            if n and n ~= "" then
                fw_name = n
            end
        end

        if line:match("^SHA256FAIL|") then
            sha256_fail = true
        end
    end

    if sha256_fail then
        download_ok = false
    end

    local logs = {}
    local start_idx = offset + 1
    if start_idx < 1 then
        start_idx = 1
    end

    for i = start_idx, total_lines do
        local line = lines[i]
        local pct, size, total, rate = line:match("^PROGRESS|(%d+)|(%d+)|(%d+)|(%-?%d+)$")

        if pct then
            local speed_text = human_bytes(rate) .. "/s"
            if tonumber(total) and tonumber(total) > 0 then
                logs[#logs + 1] = tr("Download progress: ") .. pct .. "% (" .. human_bytes(size) .. "/" .. human_bytes(total) .. "), " .. tr("Speed: ") .. speed_text
            else
                logs[#logs + 1] = tr("Download progress: ") .. human_bytes(size) .. ", " .. tr("Speed: ") .. speed_text
            end
        else
            local status2, done_size, done_total, target2 = line:match("^DONE|([A-Z]+)|(%d+)|(%d+)|(.+)$")

            if status2 then
                if status2 == "OK" then
                    if tonumber(done_total) and tonumber(done_total) > 0 then
                        logs[#logs + 1] = tr("Download finished: ") .. human_bytes(done_size) .. "/" .. human_bytes(done_total)
                    else
                        logs[#logs + 1] = tr("Download finished: ") .. human_bytes(done_size)
                    end

                    local name2 = tostring(target2 or ""):match("/tmp/wrtpilot_(.+)$")
                    if name2 and name2 ~= "" then
                        logs[#logs + 1] = name2 .. tr(" downloaded successfully")
                    end
                else
                    logs[#logs + 1] = tr("Firmware download failed, please check network or GitHub repository")
                end
            else
                local sha256ok_hash = line:match("^SHA256OK|([a-f0-9]+)$")
                if sha256ok_hash then
                    logs[#logs + 1] = tr("SHA256 verification passed: ") .. sha256ok_hash
                else
                    local comp, exp = line:match("^SHA256FAIL|([a-f0-9]+)|([a-f0-9]+)$")
                    if comp then
                        logs[#logs + 1] = tr("SHA256 verification failed, upgrade cancelled")
                        logs[#logs + 1] = tr("  Expected: ") .. exp
                        logs[#logs + 1] = tr("  Got:      ") .. comp
                    else
                        local err_line = line:match("^ERR|(.+)$")
                        if err_line and trim(err_line) ~= "" then
                            logs[#logs + 1] = err_line
                        end
                    end
                end
            end
        end
    end

    json_resp({
        ok = true,
        done = done,
        download_ok = download_ok,
        fw_name = fw_name,
        logs = logs,
        next_offset = total_lines
    })
end

function action_upgrade()
    local keep_config = to_bool(http.formvalue("keep_config")) and "1" or "0"
    local fw_name = trim(http.formvalue("fw_name") or "")

    local logs = {}

    -- Prevent path traversal: only allow safe filenames.
    if fw_name == "" or not fw_name:match("^[%w%._%-]+$") then
        logs[#logs + 1] = tr("Invalid firmware file name")
        json_resp({ ok = false, logs = logs })
        return
    end

    local fw_path = "/tmp/wrtpilot_" .. fw_name
    if not fs.access(fw_path) then
        logs[#logs + 1] = tr("Firmware file not found, please download again")
        json_resp({ ok = false, logs = logs })
        return
    end

    -- Recalculate SHA256 immediately before starting sysupgrade.
    local verified_sha = trim(read_first_line(fw_path .. ".sha256.ok"))
    local actual_sha = trim(sys.exec(
        "sha256sum " .. util.shellquote(fw_path)
        .. " 2>/dev/null | awk '{print $1}'"
    ))

    if #verified_sha ~= 64
        or verified_sha ~= actual_sha
        or not actual_sha:match("^[a-f0-9]+$") then
        logs[#logs + 1] = tr("Firmware SHA256 verification failed, upgrade cancelled")
        json_resp({ ok = false, logs = logs })
        return
    end

    -- Preserve the previous successfully recorded firmware.
    local old_selected_release = uci:get(CFG, SEC, "selected_release")

    -- Record the candidate only after explicit user confirmation and
    -- successful SHA256 verification.
    set_cfg(fw_name, keep_config)

    local keep_flag = (keep_config == "1") and "" or "-n"
    local up_cmd = "/sbin/sysupgrade "
        .. keep_flag
        .. " "
        .. util.shellquote(fw_path)

    -- If sysupgrade returns an error, restore the previous firmware record.
    -- A successful sysupgrade normally reboots the device before this
    -- rollback branch can run.
    local rollback_command

    if old_selected_release ~= nil then
        rollback_command = "uci -q set "
            .. util.shellquote(
                CFG .. "." .. SEC .. ".selected_release="
                .. old_selected_release
            )
    else
        rollback_command = "uci -q delete "
            .. util.shellquote(
                CFG .. "." .. SEC .. ".selected_release"
            )
    end

    rollback_command = rollback_command
        .. " && uci -q commit "
        .. util.shellquote(CFG)

    local background_script = table.concat({
        "sleep 2",
        up_cmd,
        "upgrade_rc=$?",
        "if [ \"$upgrade_rc\" -ne 0 ]; then",
        rollback_command,
        "logger -t wrtpilot 'sysupgrade failed; previous firmware record restored'",
        "exit \"$upgrade_rc\"",
        "fi"
    }, "; ")

    local bg = "("
        .. background_script
        .. ") >/tmp/wrtpilot-upgrade.log 2>&1 &"

    local launch_rc = sys.call(bg)

    if launch_rc ~= 0 then
        -- The background upgrade process could not be started.
        if old_selected_release ~= nil then
            uci:set(CFG, SEC, "selected_release", old_selected_release)
        else
            uci:delete(CFG, SEC, "selected_release")
        end

        uci:commit(CFG)

        logs[#logs + 1] = tr("Unable to start system upgrade")
        json_resp({ ok = false, logs = logs })
        return
    end

    logs[#logs + 1] = tr("Starting system upgrade")
    logs[#logs + 1] = (keep_config == "1")
        and tr("Upgrade mode: keep configuration")
        or tr("Upgrade mode: do not keep configuration")

    json_resp({
        ok = true,
        logs = logs,
        rebooting = true
    })
end

function action_backup()
    local tmp = "/tmp/wrtpilot-backup.tar.gz"
    fs.unlink(tmp)

    local rc = sys.call("sysupgrade --create-backup " .. util.shellquote(tmp) .. " >/dev/null 2>&1")
    if rc ~= 0 or not fs.access(tmp) then
        http.status(500, "Internal Server Error")
        http.prepare_content("text/plain; charset=utf-8")
        http.write(tr("Backup failed"))
        return
    end

    local st = fs.stat(tmp)
    local hostname = trim(sys.exec("cat /proc/sys/kernel/hostname 2>/dev/null"))
    if hostname == "" then
        hostname = "OpenWrt"
    end
    hostname = hostname:gsub("[^%w%._%-]", "_")

    local fname = "backup-" .. hostname .. "-" .. os.date("%Y-%m-%d") .. ".tar.gz"
    http.header("Content-Disposition", 'attachment; filename="' .. fname .. '"')

    if st then
        http.header("Content-Length", tostring(st.size))
    end

    http.prepare_content("application/octet-stream")

    local f = io.open(tmp, "rb")
    if f then
        repeat
            local chunk = f:read(65536)
            if chunk then
                http.write(chunk)
            end
        until not chunk

        f:close()
        fs.unlink(tmp)
    end
end
