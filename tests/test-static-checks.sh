#!/bin/sh
# WrtPilot repository static validation.
# Copyright (C) 2026 smallprogram
# Copyright (C) 2026 cheery-wen (modifications)

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

echo "[static] Validate GitHub Actions YAML"
python3 - <<'PY'
import pathlib
import yaml

workflow = pathlib.Path(".github/workflows/compile with openwrt sdk.yml")
with workflow.open(encoding="utf-8") as handle:
    yaml.safe_load(handle)
print("PASS: workflow YAML parses")
PY

echo "[static] Validate Lua 5.1 syntax"
find luci-app-wrtpilot tests -type f -name '*.lua' -exec luac5.1 -p {} +
luac5.1 -p luci-app-wrtpilot/root/usr/libexec/wrtpilot-auto-upgrade
echo "PASS: all Lua files parse with Lua 5.1"

echo "[static] Validate shell syntax"
sh -n luci-app-wrtpilot/root/etc/uci-defaults/99-wrtpilot-defaults
sh -n tests/test-workflow-po-version.sh
sh -n tests/test-static-checks.sh
echo "PASS: shell scripts parse"

echo "[static] Validate PO/POT syntax and formatting"
msgfmt --check-format -o /dev/null luci-app-wrtpilot/po/en/wrtpilot.po
msgfmt --check-format -o /dev/null luci-app-wrtpilot/po/zh_Hans/wrtpilot.po
msgfmt --check-format -o /dev/null luci-app-wrtpilot/po/templates/wrtpilot.pot

echo "[static] Compare translation catalogs with POT"
msgcmp --quiet luci-app-wrtpilot/po/en/wrtpilot.po luci-app-wrtpilot/po/templates/wrtpilot.pot
msgcmp --quiet luci-app-wrtpilot/po/zh_Hans/wrtpilot.po luci-app-wrtpilot/po/templates/wrtpilot.pot

echo "[static] Ensure every non-header POT translation is empty"
python3 - <<'PY'
import pathlib
import re

path = pathlib.Path("luci-app-wrtpilot/po/templates/wrtpilot.pot")
content = path.read_text(encoding="utf-8")
entries = re.split(r"\n\s*\n", content.strip())
checked = 0

for entry in entries:
    if not re.search(r'^msgid\s+', entry, re.M):
        continue
    match = re.search(r'^msgid\s+"(.*)"\s*$', entry, re.M)
    if match and match.group(1) == "":
        continue
    msgstr = re.search(r'^msgstr\s+"(.*)"\s*$', entry, re.M)
    if not msgstr or msgstr.group(1) != "":
        raise SystemExit("Non-empty or malformed POT msgstr found:\n" + entry)
    checked += 1

if checked == 0:
    raise SystemExit("No non-header POT entries were checked")
print(f"PASS: {checked} non-header POT msgstr entries are empty")
PY

echo "PASS: WrtPilot static checks completed"
