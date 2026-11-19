WrtPilot

OpenWrt Firmware Upgrade Pilot

面向 OpenWrt 的 LuCI 固件升级工具，通过 Web 管理界面获取 GitHub Release、筛选固件、下载并校验固件，以及执行手动或自动升级。

""License" (https://img.shields.io/badge/License-GPL--3.0--only-blue.svg?style=flat-square)" (luci-app-wrtpilot/LICENSE)
""OpenWrt" (https://img.shields.io/badge/OpenWrt-LuCI-informational?style=flat-square&logo=openwrt)" (https://openwrt.org/)

"🇨🇳 中文说明" (#中文说明) · "🇬🇧 English" (#english)

---

界面预览

<div align="center">
  <img src="img/cn.png" alt="WrtPilot 中文界面" width="48%">
  <img src="img/cn_update.png" alt="WrtPilot 中文固件升级界面" width="48%">
</div><div align="center">
  <img src="img/en.png" alt="WrtPilot English interface" width="48%">
  <img src="img/en_update.png" alt="WrtPilot English firmware upgrade interface" width="48%">
</div>---

中文说明

项目简介

WrtPilot 是一个用于 OpenWrt 的 LuCI 固件升级应用。

它将固件更新检查、Release 资产浏览、固件筛选、下载、SHA256 完整性校验和系统升级整合在 LuCI 页面中，方便用户通过路由器 Web 管理界面完成固件更新。

WrtPilot 使用固定的固件仓库：

固件仓库： "cheery-wen/OpenWrt" (https://github.com/cheery-wen/OpenWrt)

固件仓库地址由后端固定，页面不提供仓库地址修改入口，前端提交的仓库参数不会改变实际固件来源。

功能说明

1. 系统与 Release 状态

- 获取固定 GitHub 仓库的最新 Release。
- 显示当前系统安装时间。
- 显示最新 Release 版本。
- 显示 Release 发布时间。
- 显示 Release 固件资产数量。
- 根据系统安装时间与 Release 发布时间给出检查结论。
- 当最新 Release 尚未上传固件资产时，尝试使用已有固件资产的上一版本 Release。
- 支持手动刷新 Release 状态。

2. 固件资产管理

- 展示 Release 中的固件资产。
- 支持多关键词模糊搜索。
- 支持按文件扩展名筛选固件。
- 支持启用或关闭扩展名筛选。
- 支持自定义有效固件扩展名。
- 使用系统记录的上次升级固件名称辅助识别对应固件类型。

固件名称前面的日期时间前缀仅在名称比较时忽略，不作为固件匹配条件，也不会修改实际资产名称或下载地址。

3. 手动下载与升级

手动升级由用户主动选择固件并确认执行。

执行流程：

1. 获取最新 Release 信息。
2. 选择需要升级的固件资产。
3. 选择是否保留现有配置。
4. 下载固件至路由器临时目录。
5. 下载完成后验证 SHA256。
6. 校验通过后显示升级确认窗口。
7. 用户明确确认后，才向系统提交升级请求。
8. 系统启动升级程序并重新启动设备。

用户可以取消升级确认。取消后不会启动刷写操作。

下载完成并不代表设备已经开始升级，必须经过用户确认。

4. 固件完整性校验

WrtPilot 使用 GitHub Release 资产提供的 SHA256 摘要验证下载文件。

- 下载前检查固件资产提供的 SHA256 信息。
- 下载完成后计算本地文件 SHA256。
- 校验失败时取消升级。
- 后端在执行升级前再次检查固件文件及其校验标记。

5. 自动升级

WrtPilot 提供定时自动升级脚本，由系统 cron 每天执行一次，默认时间为路由器本地时间 00:00。

自动升级不是根据设备型号猜测固件，也不固定某一种架构、文件系统或固件扩展名。

它使用系统配置中记录的上次升级固件名称作为匹配依据。

自动升级执行流程：

1. 检查系统是否存在上次升级固件名称记录。
2. 如果记录为空、缺失或无法读取，立即终止。
3. 从记录的固件名称中动态提取固件类型。
4. 获取固定仓库的最新 Release。
5. 在最新 Release 中查找相同固件类型的资产。
6. 只有唯一匹配时才继续。
7. 检查匹配资产的 SHA256 摘要。
8. 下载固件并验证 SHA256。
9. 再次检查固件记录及升级任务状态。
10. 检查通过后调用系统升级程序。

以下情况不会执行自动刷写：

- 没有上次升级固件名称记录。
- 固件名称无法识别出有效类型。
- 没有匹配的固件资产。
- 存在多个匹配的固件资产。
- 固件资产缺少有效 SHA256 摘要。
- 固件下载失败。
- SHA256 校验失败。
- 检测到手动下载或其他系统升级任务。
- 下载过程中系统记录的固件名称发生变化。

自动升级采用保守处理方式，必要信息缺失或检查未通过时，跳过本次升级。

注意： 自动升级脚本由安装时的 defaults 配置注册为每日定时任务。系统存在有效的上次升级固件名称记录后，定时任务会按上述规则检查并可能自动执行升级。自动升级可能导致设备重启，请在使用前了解这一行为。

6. 配置与系统备份

- 支持保留配置升级。
- 支持不保留配置升级。
- 保存固件获取超时时间。
- 保存固件扩展名筛选设置。
- 提供系统配置备份下载入口。

7. 中英文界面

- 简体中文翻译。
- 英文翻译。
- 使用 LuCI 标准翻译目录和语言包机制。

安装方法

前往 "WrtPilot Releases" (https://github.com/cheery-wen/WrtPilot/releases) 下载对应的软件包。

WrtPilot 提供两种软件包格式：

- IPK：适用于使用 opkg 的 OpenWrt 系统。
- APK：适用于使用 apk 的 OpenWrt 系统。

中文界面还需要安装对应的中文语言包。

APK 安装

将主程序和中文语言包上传至路由器 "/tmp" 目录，然后执行：

apk add --allow-untrusted --repositories-file /dev/null /tmp/luci-app-wrtpilot-*.apk
apk add --allow-untrusted --repositories-file /dev/null /tmp/luci-i18n-wrtpilot-zh-cn-*.apk

IPK 安装

将主程序和中文语言包上传至路由器 "/tmp" 目录，然后执行：

opkg install /tmp/luci-app-wrtpilot_*.ipk
opkg install /tmp/luci-i18n-wrtpilot-zh-cn_*.ipk

安装完成后，在 LuCI 菜单中进入：

系统 → WrtPilot 固件升级

配置说明

配置文件：

"/etc/config/wrtpilot"

当前默认配置：

config wrtpilot 'main'
    option selected_release ''
    option keep_config '1'
    option fetch_timeout '15'
    option filter_ext_enabled '1'
    option valid_extensions '.img .img.gz .bin .tar .itb .trx .chk .dlf .ari'

配置项| 说明
"selected_release"| 系统记录的上次升级固件名称，也是自动升级识别固件类型的依据
"keep_config"| 是否保留配置，"1" 为保留，"0" 为不保留
"fetch_timeout"| 获取 Release 信息的超时时间，单位为秒
"filter_ext_enabled"| 是否启用有效扩展名筛选
"valid_extensions"| 有效固件扩展名列表

固件来源固定在应用后端，不通过 UCI 配置修改。

GitHub Actions 编译

项目提供 GitHub Actions SDK 编译工作流：

".github/workflows/compile with openwrt sdk.yml"

工作流支持手动触发及仓库事件触发，主要执行以下任务：

1. 读取 Makefile 中的主程序版本和 Release 版本。
2. 检查 GitHub 最新 Release。
3. 检查主程序 IPK、APK 及中文语言包 IPK、APK 是否齐全。
4. 检查中文语言包自身的版本。
5. 资产缺失或版本不一致时启动编译。
6. 使用 OpenWrt SDK 分别构建 IPK 和 APK。
7. 收集主程序及中文语言包。
8. 上传或覆盖对应 Release 资产。

编译目标：

软件包| SDK 编译目标
IPK| "x86_64-24.10.6"
APK| "x86_64"

主程序版本由以下文件管理：

"luci-app-wrtpilot/Makefile"

中文语言包版本遵循 LuCI 的 "PKG_PO_VERSION" 计算规则，与主程序版本分别检查。

项目结构

WrtPilot/
├── .github/
│   └── workflows/
│       └── compile with openwrt sdk.yml
├── img/
│   ├── cn.png
│   ├── cn_update.png
│   ├── en.png
│   └── en_update.png
├── luci-app-wrtpilot/
│   ├── Makefile
│   ├── LICENSE
│   ├── luasrc/
│   │   ├── controller/
│   │   │   └── wrtpilot.lua
│   │   └── view/
│   │       └── wrtpilot/
│   │           └── main.htm
│   ├── po/
│   │   ├── en/
│   │   ├── zh_Hans/
│   │   └── templates/
│   └── root/
│       ├── etc/
│       │   ├── config/
│       │   │   └── wrtpilot
│       │   └── uci-defaults/
│       │       └── 99-wrtpilot-defaults
│       └── usr/
│           └── libexec/
│               └── wrtpilot-auto-upgrade
└── README.md

项目地址

- GitHub 仓库："cheery-wen/WrtPilot" (https://github.com/cheery-wen/WrtPilot)
- 固件仓库："cheery-wen/OpenWrt" (https://github.com/cheery-wen/OpenWrt)
- 软件包发布："WrtPilot Releases" (https://github.com/cheery-wen/WrtPilot/releases)

许可证

本项目采用 GNU General Public License v3.0 only。

详细内容请参阅 "LICENSE" (luci-app-wrtpilot/LICENSE)。

---

English

Introduction

WrtPilot is a LuCI firmware upgrade application for OpenWrt.

It integrates GitHub Release checking, firmware asset browsing, filtering, downloading, SHA256 verification, and system upgrades into the router's web interface.

WrtPilot uses a fixed firmware repository:

Firmware repository: "cheery-wen/OpenWrt" (https://github.com/cheery-wen/OpenWrt)

The repository is enforced by the backend and cannot be changed through the web interface.

Features

1. System and Release Status

- Fetches the latest Release from the fixed GitHub repository.
- Displays the current system installation time.
- Displays the latest Release version and publication time.
- Displays the total number of Release assets.
- Compares the Release publication time with the system installation time.
- Falls back to a previous Release containing firmware assets when the latest Release has no uploaded assets.
- Supports manual status refresh.

2. Firmware Asset Management

- Lists firmware assets from GitHub Releases.
- Supports multi-keyword fuzzy search.
- Filters firmware by file extension.
- Allows extension filtering to be enabled or disabled.
- Supports a customizable list of valid firmware extensions.
- Uses the firmware name recorded by the system to help identify the corresponding firmware type.

A leading build date/time prefix is ignored only during firmware-name comparison. It is not used as a matching condition, and the original asset filename and download URL remain unchanged.

3. Manual Download and Upgrade

The manual upgrade process requires explicit user confirmation.

1. Fetch the latest Release information.
2. Select a firmware asset.
3. Choose whether to preserve the current configuration.
4. Download the firmware to the router's temporary directory.
5. Verify its SHA256 digest.
6. Display an upgrade confirmation dialog after successful verification.
7. Start the system upgrade only after the user confirms.
8. The device reboots as part of the system upgrade.

Cancelling the confirmation does not start the flashing process.

4. Firmware Integrity Verification

WrtPilot verifies downloaded firmware using the SHA256 digest provided by GitHub Release assets.

- Checks the asset's SHA256 information.
- Calculates the local file's SHA256 after downloading.
- Cancels the upgrade if verification fails.
- Performs another firmware-file and verification-marker check before starting the upgrade.

5. Automatic Upgrade

WrtPilot includes an automatic upgrade script scheduled by cron once per day, by default at 00:00 router local time.

Automatic upgrades do not rely on a fixed device model, architecture, filesystem, or firmware extension.

The script uses the firmware name recorded in the system configuration as its matching reference.

The process:

1. Checks whether the previously upgraded firmware name is recorded.
2. Stops if the record is empty, missing, or unreadable.
3. Dynamically extracts the firmware type from the recorded name.
4. Fetches the latest Release from the fixed repository.
5. Searches for assets matching the recorded firmware type.
6. Continues only when exactly one asset matches.
7. Checks the asset's SHA256 digest.
8. Downloads the firmware and verifies its SHA256 digest.
9. Rechecks the firmware record and upgrade-task status.
10. Invokes the system upgrade utility only when all checks pass.

Automatic flashing is skipped when:

- The previous firmware record is missing or unreadable.
- The firmware type cannot be identified.
- No asset matches.
- Multiple assets match.
- The asset has no valid SHA256 digest.
- The download fails.
- SHA256 verification fails.
- A manual download or another system upgrade is active.
- The recorded firmware name changes during the download process.

The automatic upgrade script follows a fail-closed approach: missing information or failed checks prevent automatic flashing.

Important: The daily cron task is registered by the installation defaults. Once a valid previous firmware name is recorded, the task may automatically download and install a matching firmware from the latest Release. Automatic upgrades can reboot the router.

6. Configuration and Backup

- Supports upgrades with configuration preservation.
- Supports upgrades without configuration preservation.
- Saves the Release fetch timeout.
- Saves firmware extension filtering settings.
- Provides a system configuration backup download entry.

7. Languages

- Simplified Chinese.
- English.
- LuCI translation package support.

Installation

Download the appropriate packages from "WrtPilot Releases" (https://github.com/cheery-wen/WrtPilot/releases).

Two package formats are provided:

- IPK for OpenWrt systems using opkg.
- APK for OpenWrt systems using apk.

Install the corresponding Chinese translation package if you want the Chinese interface.

APK

Upload the main package and Chinese translation package to "/tmp", then run:

apk add --allow-untrusted --repositories-file /dev/null /tmp/luci-app-wrtpilot-*.apk
apk add --allow-untrusted --repositories-file /dev/null /tmp/luci-i18n-wrtpilot-zh-cn-*.apk

IPK

Upload the main package and Chinese translation package to "/tmp", then run:

opkg install /tmp/luci-app-wrtpilot_*.ipk
opkg install /tmp/luci-i18n-wrtpilot-zh-cn_*.ipk

After installation, open:

System → WrtPilot Firmware Upgrade

Configuration

Configuration file:

"/etc/config/wrtpilot"

Default configuration:

config wrtpilot 'main'
    option selected_release ''
    option keep_config '1'
    option fetch_timeout '15'
    option filter_ext_enabled '1'
    option valid_extensions '.img .img.gz .bin .tar .itb .trx .chk .dlf .ari'

Option| Description
"selected_release"| Previously upgraded firmware name and the reference for automatic firmware-type matching
"keep_config"| Preserve configuration when upgrading: "1" to keep, "0" not to keep
"fetch_timeout"| Release fetch timeout in seconds
"filter_ext_enabled"| Enables or disables valid-extension filtering
"valid_extensions"| List of valid firmware extensions

The firmware repository is fixed in the application backend and is not configurable through UCI.

GitHub Actions Build

The project provides a GitHub Actions SDK build workflow:

".github/workflows/compile with openwrt sdk.yml"

The workflow supports manual and repository-event triggers. It:

1. Reads the main package version and release number from the Makefile.
2. Checks the latest GitHub Release.
3. Checks for the main IPK, main APK, Chinese translation IPK, and Chinese translation APK.
4. Calculates and checks the Chinese translation package version independently.
5. Starts a build when assets are missing or outdated.
6. Builds IPK and APK packages using the OpenWrt SDK.
7. Collects the main package and Chinese translation package.
8. Uploads or overwrites the corresponding Release assets.

Build targets:

Package| SDK target
IPK| "x86_64-24.10.6"
APK| "x86_64"

The main package version is managed in:

"luci-app-wrtpilot/Makefile"

The Chinese translation package version follows LuCI's "PKG_PO_VERSION" calculation and is checked separately from the main package version.

Repository Structure

WrtPilot/
├── .github/
│   └── workflows/
│       └── compile with openwrt sdk.yml
├── img/
│   ├── cn.png
│   ├── cn_update.png
│   ├── en.png
│   └── en_update.png
├── luci-app-wrtpilot/
│   ├── Makefile
│   ├── LICENSE
│   ├── luasrc/
│   │   ├── controller/
│   │   │   └── wrtpilot.lua
│   │   └── view/
│   │       └── wrtpilot/
│   │           └── main.htm
│   ├── po/
│   │   ├── en/
│   │   ├── zh_Hans/
│   │   └── templates/
│   └── root/
│       ├── etc/
│       │   ├── config/
│       │   │   └── wrtpilot
│       │   └── uci-defaults/
│       │       └── 99-wrtpilot-defaults
│       └── usr/
│           └── libexec/
│               └── wrtpilot-auto-upgrade
└── README.md

Links

- GitHub repository: "cheery-wen/WrtPilot" (https://github.com/cheery-wen/WrtPilot)
- Firmware repository: "cheery-wen/OpenWrt" (https://github.com/cheery-wen/OpenWrt)
- Releases: "WrtPilot Releases" (https://github.com/cheery-wen/WrtPilot/releases)

License

This project is licensed under the GNU General Public License v3.0 only.

See "LICENSE" (luci-app-wrtpilot/LICENSE) for details.
