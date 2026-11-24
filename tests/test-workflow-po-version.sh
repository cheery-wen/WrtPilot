#!/bin/sh
# WrtPilot CI workflow regression test.
#
# Run from the repository root:
#   sh tests/test-workflow-po-version.sh
#
# luci.mk computes PKG_PO_VERSION from the last commit touching the po
# directory (findrev: git log -1 ... -- po). The workflow's expected i18n
# asset version must use the same scope, otherwise the asset check never
# matches and every trigger rebuilds and overwrites the Release.

set -e

WORKFLOW=".github/workflows/compile with openwrt sdk.yml"

if grep -q "log -1 --format='%ct %h' --abbrev=7 -- po" "$WORKFLOW"; then
    echo "PASS: workflow computes the i18n version from the po directory"
else
    echo "FAIL: workflow must scope the i18n version git log to '-- po' (luci.mk findrev)"
    exit 1
fi
