WrtPilot

OpenWrt Firmware Upgrade Pilot

基于 GitHub Releases 的 OpenWrt 固件检查、下载与升级工具。

""License" (https://img.shields.io/badge/License-GPL--3.0--only-blue.svg?style=flat-square)" (luci-app-wrtpilot/LICENSE)
""OpenWrt" (https://img.shields.io/badge/OpenWrt-Compatible-informational?style=flat-square&logo=openwrt)" (https://openwrt.org/)

"🇨🇳 中文说明" (#中文说明) · "🇬🇧 English" (#english)

---

界面预览

<div align="center">
  <img src="img/cn.png" alt="WrtPilot 中文界面" width="48%">
  <img src="img/cn_update.png" alt="WrtPilot 固件升级界面" width="48%">
</div>
<div align="center">
  <img src="img/en.png" alt="WrtPilot English interface" width="48%">
  <img src="img/en_update.png" alt="WrtPilot firmware upgrade interface" width="48%">
</div>---

中文说明

项目简介

WrtPilot 是一个用于 OpenWrt 的 LuCI 固件升级插件。

用户可以通过路由器 Web 管理界面获取 GitHub Release 信息、查看固件资产、下载固件并执行升级，无需手动查找固件下载地址或通过命令行操作。

WrtPilot 使用固定固件仓库：

"cheery-wen/OpenWrt" (https://github.com/cheery-wen/OpenWrt)

固件仓库地址由后端固定，不提供前端仓库地址修改入口。

主要功能

- 固件状态检查：获取固定 GitHub 仓库的最新 Release 信息，显示版本、发布时间和固件资产数量。
- 固件资产展示：列出 Release 中可供选择的固件文件。
- 固件筛选：支持按文件扩展名过滤固件，并允许用户自定义有效扩展名。
- 固件名称匹配：根据上次更新固件名称辅助筛选最新 Release 中的对应固件。
- 模糊搜索：支持多关键词搜索，方便查找固件资产。
- 下载与校验：下载固件，并使用 SHA256 摘要验证文件完整性。
- 手动升级确认：固件下载和校验完成后，由用户明确确认是否执行升级；取消确认不会启动刷写。
- 配置保留：支持保留配置或不保留配置两种升级方式。
- 自动升级：每天定时检查最新 Release，根据系统记录的上次更新固件名称动态识别固件类型，并匹配对应资产。
- 自动升级安全检查：没有上次更新固件记录、固件类型无法识别、匹配结果不唯一、SHA256 摘要无效或校验失败、下载失败以及存在其他升级任务时，均不会启动自动刷写。
- 系统备份：提供系统配置备份入口。
- 中英文界面：支持中文和英文界面。

自动升级规则

自动升级使用系统中记录的上次更新固件名称作为匹配依据，不根据设备型号或预设的固件格式推测目标固件。

执行过程：

1. 检查系统是否存在上次更新固件记录。
2. 从记录的固件名称中提取固件类型。
3. 获取固定仓库的最新 Release。
4. 在最新 Release 中查找相同固件类型的资产。
5. 只有唯一匹配时才继续。
6. 检查资产 SHA256 摘要并下载固件。
7. 下载完成后进行 SHA256 校验。
8. 再次检查升级任务状态及固件记录。
9. 检查全部通过后调用系统升级程序。

日期时间前缀只在固件名称比较时忽略，不作为固件匹配条件，也不会修改实际资产文件名。

自动升级采用保守策略：任何必要信息缺失或检查失败，均跳过本次自动升级。

安装方法

从项目的 GitHub Releases 下载对应的软件包。

项目地址：

https://github.com/cheery-wen/WrtPilot

OpenWrt APK 软件包

将下载的软件包上传至路由器 "/tmp" 目录，然后执行：

apk add --allow-untrusted --repositories-file /dev/null /tmp/luci-app-wrtpilot-版本号.apk
apk add --allow-untrusted --repositories-file /dev/null /tmp/luci-i18n-wrtpilot-zh-cn-版本号.apk

OpenWrt IPK 软件包

将下载的软件包上传至路由器 "/tmp" 目录，然后执行：

opkg install /tmp/luci-app-wrtpilot_版本号_all.ipk
opkg install /tmp/luci-i18n-wrtpilot-zh-cn_版本号_all.ipk

安装完成后，在 LuCI 菜单中进入：

系统 → WrtPilot 固件升级

源码编译

本项目提供 GitHub Actions SDK 编译工作流。

支持生成：

- OpenWrt IPK 软件包
- OpenWrt APK 软件包
- 中文语言包

软件包版本由 "luci-app-wrtpilot/Makefile" 中的 "PKG_VERSION" 管理。

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

---

English

Introduction

WrtPilot is a LuCI firmware upgrade application for OpenWrt.

It allows users to check GitHub Releases, browse firmware assets, download firmware, verify file integrity, and perform system upgrades through the router's web interface.

WrtPilot uses a fixed firmware repository:

"cheery-wen/OpenWrt" (https://github.com/cheery-wen/OpenWrt)

The repository is enforced by the backend and cannot be changed through the web interface.

Features

- Firmware status checking: Retrieves the latest Release information from the fixed GitHub repository.
- Firmware asset listing: Displays available firmware assets.
- Extension filtering: Filters firmware files by extension with a customizable extension list.
- Firmware name matching: Uses the previously updated firmware name to help identify the corresponding asset in the latest Release.
- Fuzzy search: Supports multi-keyword firmware searches.
- Download and verification: Downloads firmware and verifies its SHA256 digest.
- Manual upgrade confirmation: Requires explicit user confirmation before starting the system upgrade.
- Configuration preservation: Supports both keep-configuration and no-keep-configuration upgrade modes.
- Automatic upgrades: Checks for updates daily and dynamically identifies the firmware type from the previously updated firmware name.
- Automatic upgrade safeguards: Skips automatic flashing when the previous firmware record is missing, the asset match is ambiguous, SHA256 verification fails, downloading fails, or another upgrade task is active.
- System backup: Provides access to system configuration backup.
- Bilingual interface: Supports Chinese and English.

Automatic Upgrade Rules

Automatic upgrades use the firmware name recorded by the system as the matching reference.

The process does not assume a specific device model or hardcode a firmware format.

The system extracts the firmware type from the recorded name, searches the latest Release for a unique matching asset, downloads it, verifies its SHA256 digest, and checks for conflicting upgrade tasks before invoking the system upgrade utility.

If any required information or verification is missing or fails, automatic flashing is skipped.

Installation

Download the appropriate packages from the project's GitHub Releases:

https://github.com/cheery-wen/WrtPilot

Install the main package and the corresponding Chinese language package using the package manager available on your OpenWrt system.

Build

GitHub Actions provides SDK build workflows for:

- OpenWrt IPK packages
- OpenWrt APK packages
- Chinese language packages

The package version is managed in "luci-app-wrtpilot/Makefile".

---

License

This project is licensed under the GNU General Public License v3.0 only.

See "LICENSE" (luci-app-wrtpilot/LICENSE) for details.