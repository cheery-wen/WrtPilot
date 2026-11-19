
WrtPilot

WrtPilot（OpenWrt Firmware Upgrade Pilot） 是一款基于 LuCI 的 OpenWrt 固件升级管理插件，通过 GitHub Releases 获取固件信息、筛选固件资产、下载固件并进行 SHA256 校验，为 OpenWrt 提供手动升级和自动升级功能。

项目地址

- 项目仓库："cheery-wen/WrtPilot" (https://github.com/cheery-wen/WrtPilot)

功能特点

1. 系统与 Release 状态

- 获取固件仓库最新 Release 信息。
- 显示系统安装时间。
- 显示最新 Release 名称及发布时间。
- 显示固件资产数量。
- 显示上次确认升级的固件名称。
- 显示固件检查结果及相关日志。
- 支持查看最新 Release 更新说明。
- 当最新 Release 暂时没有可用固件资产时，尝试使用上一个包含固件资产的 Release。

2. 固件选择与筛选

- 获取 GitHub Release 中的固件资产列表。
- 支持按固件名称进行模糊搜索。
- 支持按有效扩展名过滤固件。
- 支持自定义有效固件扩展名。
- 根据上次记录的固件名称自动进行筛选。
- 不限定某一种设备型号或固件格式。

默认有效扩展名：

.img
.img.gz
.bin
.tar
.itb
.trx
.chk
.dlf
.ari

3. 手动下载与升级

手动升级采用分阶段操作：

1. 获取最新 Release。
2. 选择需要升级的固件。
3. 下载固件到路由器临时目录。
4. 对下载文件进行 SHA256 校验。
5. 校验通过后显示升级确认窗口。
6. 用户确认后才执行系统升级。
7. 用户取消则不会执行刷写操作。

下载和校验完成不代表系统会自动刷写，必须经过用户明确确认。

取消升级时，已下载的固件文件会予以保留。

支持选择是否保留现有配置进行升级。

4. 自动固件升级

WrtPilot 提供每日自动检查功能。

自动升级使用「系统与 Release 状态」中记录的上次确认升级固件名称作为匹配依据：

1. 读取上次记录的固件名称。
2. 从固件名称中提取固件类型。
3. 获取固定固件仓库的最新 Release。
4. 根据提取的固件类型匹配最新 Release 中的固件资产。
5. 只有唯一匹配时才继续。
6. 下载固件并验证 SHA256。
7. 校验通过后执行系统升级。

自动升级采用严格的失败停止原则：

- 没有上次固件记录，不执行自动升级。
- 无法识别固件类型，不执行自动升级。
- 没有匹配的固件，不执行自动升级。
- 匹配到多个固件，不执行自动升级。
- 缺少有效 SHA256 摘要，不执行自动升级。
- 固件下载失败，不执行自动升级。
- SHA256 校验失败，不执行自动升级。
- 已有手动下载或系统升级任务时，不执行自动升级。
- 固件名称与上次记录的固件相同（忽略开头的日期时间前缀），不重复升级。

自动匹配不固定设备型号、架构、文件系统或固件扩展名，而是根据已有固件名称动态确定匹配类型。

自动升级任务由默认配置脚本加入系统计划任务，每天执行一次：

0 0 * * * lua /usr/libexec/wrtpilot-auto-upgrade

注意：自动升级不需要人工确认。 当匹配条件及 SHA256 校验全部通过后，脚本会直接调用系统升级程序。使用前请确认固件来源和自动升级行为符合自己的使用需求。

5. 固件完整性校验

- 支持读取 GitHub Release 提供的 SHA256 摘要。
- 下载完成后重新计算文件 SHA256。
- 校验结果与 Release 摘要进行比较。
- 校验失败时取消升级。
- 手动升级和自动升级均执行固件完整性校验。

6. 配置与兼容处理

- 支持保留配置升级或不保留配置升级。
- 支持下载配置备份。
- 支持设置 GitHub Release 请求超时时间。
- 支持自定义有效固件扩展名。
- 首次运行时自动创建 WrtPilot UCI 配置。
- 兼容迁移旧 GHFU 的相关用户设置。
- 迁移时不继承旧版可修改的 GitHub 仓库设置。

LuCI 界面

安装后，在 OpenWrt 管理界面中进入：

系统 → WrtPilot 固件升级

主要包含：

- 基础配置
- 系统与 Release 状态
- 可用固件
- 固件模糊搜索
- 有效扩展名过滤
- 操作日志
- 下载与升级确认
- 配置备份

安装方式

进入 "WrtPilot Releases" (https://github.com/cheery-wen/WrtPilot/releases)，下载对应的软件包。

项目自动构建并发布以下两种软件包格式：

- IPK：用于采用 opkg 的 OpenWrt 系统。
- APK：用于采用 apk 的 OpenWrt 系统。

请根据路由器当前使用的软件包管理器选择对应格式，并同时安装主程序和中文语言包。

IPK 安装示例

opkg install luci-app-wrtpilot_*.ipk
opkg install luci-i18n-wrtpilot-zh-cn_*.ipk

APK 安装示例

apk add --allow-untrusted ./luci-app-wrtpilot-*.apk
apk add --allow-untrusted ./luci-i18n-wrtpilot-zh-cn-*.apk

安装完成后刷新 LuCI 页面，进入「系统 → WrtPilot 固件升级」。

软件包依赖由 Makefile 声明：

- "luci-base"
- "wget-ssl"
- "ca-bundle"

请确保系统具备相应依赖及正常访问 GitHub 的网络条件。

GitHub Actions 自动构建

项目通过 GitHub Actions 和 OpenWrt SDK 构建软件包。

当前构建流程包括：

1. 读取 Makefile 中的主程序版本及 Release 版本。
2. 检查 GitHub 最新 Release。
3. 检查主程序 IPK、APK 资产。
4. 独立计算并检查中文语言包版本。
5. 检查中文语言包 IPK、APK 资产。
6. 资产缺失或版本不一致时启动构建。
7. 使用 OpenWrt SDK 分别构建 IPK 和 APK。
8. 收集主程序及中文语言包。
9. 上传至对应 GitHub Release，并覆盖同名资产。


中文语言包版本遵循 LuCI 的 "PKG_PO_VERSION" 计算规则，与主程序版本独立处理。


许可证

本项目采用 GNU General Public License v3.0 only（GPL-3.0-only）。

完整许可证见："LICENSE" (https://github.com/cheery-wen/WrtPilot/blob/main/luci-app-wrtpilot/LICENSE)。

免责声明

固件升级涉及系统分区写入，错误的固件可能导致设备无法正常启动。

使用前请确认固件适用于自己的设备，并确保升级过程中供电稳定。

本项目不保证所有设备、所有固件及所有 OpenWrt 分支均能正常升级。使用者应自行承担固件升级及配置变更带来的风险。
