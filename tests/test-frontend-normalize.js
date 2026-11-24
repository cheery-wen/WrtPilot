// WrtPilot frontend firmware-name normalization test.
//
// Run from the repository root:
//   node tests/test-frontend-normalize.js
//
// Extracts the real normalizeFirmwareSearchName() from the LuCI template and
// checks that it strips the leading build date/time exactly like the Lua
// auto-upgrade helper (the trailing underscore after the time is optional).

'use strict';

const fs = require('fs');
const assert = require('assert');

const templatePath = process.argv[2]
    || 'luci-app-wrtpilot/luasrc/view/wrtpilot/main.htm';

const src = fs.readFileSync(templatePath, 'utf8');
const match = src.match(
    /function normalizeFirmwareSearchName\(value\)\s*\{[\s\S]*?\n    \}/
);
assert(match, 'normalizeFirmwareSearchName() not found in template');

// eslint-disable-next-line no-new-func
const normalizeFirmwareSearchName = new Function(
    match[0] + '\nreturn normalizeFirmwareSearchName;'
)();

let passed = 0;
function check(name, actual, expected) {
    assert.strictEqual(actual, expected, 'FAIL: ' + name);
    passed += 1;
    console.log('PASS: ' + name);
}

check(
    'strips date/time prefix with underscore',
    normalizeFirmwareSearchName(
        '2026.11.16-16.17_OpenWrt-v25.12.6-Stable_x86_64.img.gz'
    ),
    'openwrt-v25.12.6-stable_x86_64.img.gz'
);

check(
    'strips date/time prefix without underscore (matches Lua helper)',
    normalizeFirmwareSearchName(
        '2026.11.16-16.17OpenWrt-v25.12.6-Stable_x86_64.img.gz'
    ),
    'openwrt-v25.12.6-stable_x86_64.img.gz'
);

check(
    'keeps names without a date/time prefix unchanged except case',
    normalizeFirmwareSearchName('OpenWrt-v25.12.6-Stable_x86_64.img.gz'),
    'openwrt-v25.12.6-stable_x86_64.img.gz'
);

check(
    'empty input stays empty',
    normalizeFirmwareSearchName(''),
    ''
);

console.log('\nAll ' + passed + ' WrtPilot frontend normalization tests passed.');
