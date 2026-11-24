
-- WrtPilot automatic-upgrade helper tests.
--
-- Run from the repository root:
--   WRTPILOT_TEST_MODE=1 lua tests/test-wrtpilot-auto-upgrade.lua
--
-- The tested production script exits into its helper-only test interface before
-- loading LuCI/UCI, making network requests, downloading files or flashing.

local script_path = arg[1]
    or "luci-app-wrtpilot/root/usr/libexec/wrtpilot-auto-upgrade"

assert(
    os.getenv("WRTPILOT_TEST_MODE") == "1",
    "Run this test with WRTPILOT_TEST_MODE=1"
)

local helpers, load_error = dofile(script_path)

assert(
    type(helpers) == "table",
    "Unable to load WrtPilot test helpers: " .. tostring(load_error)
)

local passed = 0

local function check(name, condition)
    assert(condition, "FAIL: " .. name)
    passed = passed + 1
    io.write("PASS: ", name, "\n")
end

local function equal(name, actual, expected)
    check(
        name,
        actual == expected
            or (
                actual == nil
                and expected == nil
            )
    )
end

local function count(name, list, expected)
    check(
        name,
        type(list) == "table"
            and #list == expected
    )
end

-- Firmware-name normalization:
-- remove path and leading build date/time, but preserve the complete
-- remaining filename, including target, profile and extension.
local previous =
    "2026.11.16-16.17_OpenWrt-v25.12.6-Stable_x86_64_generic-squashfs-combined-efi.img.gz"

local newer =
    "2026.11.23-10.30_OpenWrt-v25.12.6-Stable_x86_64_generic-squashfs-combined-efi.img.gz"

local normalized =
    "openwrt-v25.12.6-stable_x86_64_generic-squashfs-combined-efi.img.gz"

equal(
    "strip leading date/time without changing the rest of the filename",
    helpers.normalize_firmware_name(previous),
    normalized
)

equal(
    "different build dates normalize to the same firmware name",
    helpers.normalize_firmware_name(newer),
    normalized
)

equal(
    "extract filename from a path",
    helpers.normalize_firmware_name(
        "/tmp/releases/" .. previous
    ),
    normalized
)

equal(
    "case-insensitive filename normalization",
    helpers.normalize_firmware_name(
        "OpenWrt-V25.12.6-STABLE_X86_64.img.gz"
    ),
    "openwrt-v25.12.6-stable_x86_64.img.gz"
)

-- Exact matching takes precedence over partial matches.
local exact_assets = {
    {
        name = "mirror_" .. previous,
        id = "partial"
    },
    {
        name = newer,
        id = "exact"
    }
}

local exact_matches =
    helpers.find_matching_assets(exact_assets, previous)

count("exact match takes precedence over substring match", exact_matches, 1)
equal(
    "the exact matching asset is returned",
    exact_matches[1].id,
    "exact"
)

-- GHFU-style filename containment fallback.
local partial_assets = {
    {
        name = "backup-" .. newer .. ".metadata",
        id = "partial"
    }
}

local partial_matches =
    helpers.find_matching_assets(partial_assets, previous)

count("substring fallback finds one candidate", partial_matches, 1)
equal(
    "substring fallback returns the candidate",
    partial_matches[1].id,
    "partial"
)

-- Fail-closed matching: do not silently select the first of multiple assets.
local duplicate_assets = {
    { name = newer, id = "first" },
    { name = previous, id = "second" }
}

local duplicate_matches =
    helpers.find_matching_assets(duplicate_assets, previous)

count("duplicate exact matches remain ambiguous", duplicate_matches, 2)

count(
    "no matching asset returns an empty list",
    helpers.find_matching_assets(
        { { name = "unrelated-firmware.img" } },
        previous
    ),
    0
)

count(
    "invalid asset collection returns an empty list",
    helpers.find_matching_assets("not-an-array", previous),
    0
)

count(
    "empty previous firmware name returns no matches",
    helpers.find_matching_assets(
        { { name = newer } },
        ""
    ),
    0
)

-- SHA256 validation and comparison.
local digest = string.rep("a", 64)

equal(
    "valid sha256 digest is normalized",
    helpers.valid_sha256_digest("sha256:" .. string.upper(digest)),
    digest
)

equal(
    "digest without sha256 prefix is rejected",
    helpers.valid_sha256_digest(digest),
    nil
)

equal(
    "short sha256 digest is rejected",
    helpers.valid_sha256_digest("sha256:" .. string.rep("a", 63)),
    nil
)

equal(
    "non-hex sha256 digest is rejected",
    helpers.valid_sha256_digest("sha256:" .. string.rep("g", 64)),
    nil
)

check(
    "matching SHA256 values pass",
    helpers.sha256_matches(digest, string.upper(digest))
)

check(
    "different SHA256 values fail",
    not helpers.sha256_matches(digest, string.rep("b", 64))
)

check(
    "malformed SHA256 values fail",
    not helpers.sha256_matches("not-a-hash", digest)
)

-- Automatic-upgrade enablement.
check(
    "automatic upgrade is enabled only by value 1",
    helpers.auto_upgrade_is_enabled("1")
)

check(
    "automatic upgrade remains disabled for 0",
    not helpers.auto_upgrade_is_enabled("0")
)

check(
    "automatic upgrade remains disabled for an empty value",
    not helpers.auto_upgrade_is_enabled("")
)

check(
    "automatic upgrade remains disabled for a missing value",
    not helpers.auto_upgrade_is_enabled(nil)
)

-- Recheck the recorded firmware after download.
-- This is a concurrency/safety check, so the complete filename must match.
-- A changed date/time prefix means the recorded firmware has changed.
check(
    "identical complete firmware record remains unchanged",
    helpers.firmware_record_unchanged(previous, previous)
)

check(
    "date-only change is detected as a changed firmware record",
    not helpers.firmware_record_unchanged(newer, previous)
)

check(
    "different firmware name is detected",
    not helpers.firmware_record_unchanged(
        "OpenWrt-v25.12.7-Stable-x86_64.img.gz",
        previous
    )
)

check(
    "case-only difference does not count as a changed record",
    helpers.firmware_record_unchanged(
        string.upper(previous),
        previous
    )
)

check(
    "same filename in a path remains unchanged",
    helpers.firmware_record_unchanged(
        "/tmp/releases/" .. previous,
        previous
    )
)

check(
    "missing current firmware record fails closed",
    not helpers.firmware_record_unchanged("", previous)
)

check(
    "missing original firmware record fails closed",
    not helpers.firmware_record_unchanged(newer, "")
)

-- Repeated-flash protection is separate from matching: matching ignores the
-- date/time prefix, but the no-op check compares the complete asset filename.
check(
    "identical complete firmware filename is recognized as the same build",
    helpers.firmware_is_same_build(previous, previous)
)

check(
    "same complete filename is compared case-insensitively",
    helpers.firmware_is_same_build(
        "2026.11.16-16.17_OPENWRT-V25.12.6-STABLE.img.gz",
        "2026.11.16-16.17_openwrt-v25.12.6-stable.img.gz"
    )
)

check(
    "different build date remains eligible for upgrade",
    not helpers.firmware_is_same_build(previous, newer)
)

check(
    "different firmware filename remains eligible for upgrade",
    not helpers.firmware_is_same_build(
        previous,
        "2026.11.23-10.30_OpenWrt-v25.12.7-Stable_x86_64.img.gz"
    )
)

check(
    "same filename in a path is recognized",
    helpers.firmware_is_same_build(
        "/tmp/firmware/" .. previous,
        previous
    )
)

check(
    "missing candidate filename does not count as same build",
    not helpers.firmware_is_same_build(previous, "")
)

check(
    "missing recorded filename does not count as same build",
    not helpers.firmware_is_same_build("", previous)
)

-- Existing manual downloads or sysupgrade tasks block automatic flashing.
check(
    "manual download blocks automatic upgrade",
    helpers.should_skip_for_active_tasks(true, false)
)

check(
    "active sysupgrade blocks automatic upgrade",
    helpers.should_skip_for_active_tasks(false, true)
)

check(
    "both active tasks block automatic upgrade",
    helpers.should_skip_for_active_tasks(true, true)
)

check(
    "no active task permits the next safety checks",
    not helpers.should_skip_for_active_tasks(false, false)
)

-- Stale-lock reclamation decision: a lock may only be reclaimed when its
-- recorded owner is dead, or when no owner was recorded and the grace
-- period has already elapsed.
check(
    "lock reclamation helper is exported",
    type(helpers.lock_should_reclaim) == "function"
)

check(
    "a live lock owner is never reclaimed",
    not helpers.lock_should_reclaim(true, 3600)
)

check(
    "a dead lock owner is reclaimed",
    helpers.lock_should_reclaim(false, 5)
)

check(
    "an unrecorded owner is reclaimed only after the grace period",
    helpers.lock_should_reclaim(nil, 3600)
)

check(
    "an unrecorded owner inside the grace period is respected",
    not helpers.lock_should_reclaim(nil, 5)
)

check(
    "an unknown lock age without a recorded owner fails closed",
    not helpers.lock_should_reclaim(nil, nil)
)

io.write("\nAll ", passed, " WrtPilot helper tests passed.\n")
