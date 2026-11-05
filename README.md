# Windows Disk Cleanup / Windows 磁盘清理

A Codex skill for routine cache cleanup and evidence-based deep storage audits across Windows drives. The skill identifier stays `windows-c-drive-cleanup` for existing installations.

用于 Windows 多磁盘缓存清理与深度占用排查的 Codex 技能。保留 `windows-c-drive-cleanup` 标识，兼容已有安装。

## Install / 安装

```powershell
git clone https://github.com/g1156487116-wq/windows-c-drive-cleanup-skill.git "$env:USERPROFILE\.codex\skills\windows-c-drive-cleanup"
```

For an existing clone, update from its directory with `git pull --ff-only`. Start a new agent task if the updated skill has not been discovered.

已有安装可在技能目录执行 `git pull --ff-only` 更新。更新后若尚未被识别，可新建一个 agent 任务。

## Use / 使用

After installing, tell the agent directly. 安装后，直接对 agent 说下面任意一句即可。

```text
清理C盘
清理各个盘
深度探索一下，看下还有什么内容可以清理
Clean my C drive
Audit all my Windows drives and identify deep-cleanup candidates
```

Explicit invocation also works. 也支持显式调用。

```text
Use $windows-c-drive-cleanup to inspect my drives, clean authorized candidates, and report reclaimed space.
```

## Workflow / 工作方式

The agent inventories current drives, verifies ownership and live references, and classifies each candidate. Routine cleaning covers regenerable caches. Deep cleaning can cover installer remnants, old logs, copied dependencies, models, obsolete application versions, backups and release packages after scope approval. Existing authorization carries forward. The result includes per-target failures and before/after free space.

agent 先盘点当前磁盘，核对文件用途和使用路径，再逐项判断。常规清理处理可再生成缓存。深度清理在范围明确后，可处理安装残留、旧日志、依赖副本、模型、过期软件版本、备份和发布包。已经授予的清理授权会沿用。完成后报告失败项和各盘可用空间变化。

Application versions are checked against launchers, shortcuts and uninstall registrations. Duplicates require content hashes. Agent conversation databases, personal media, project state and backups require explicit scope decisions. Folder names alone do not authorize deletion. Reports contain local paths and should remain outside this public repository.

清理软件旧版本前会检查启动器、快捷方式和卸载登记。判断重复文件会核对内容校验值。会话数据库、个人素材、项目状态和备份需明确清理范围。目录名称本身不能作为删除依据。报告包含本机路径，应保存在此公开仓库之外。

## Scripts / 脚本

Run from the skill folder in PowerShell. The deep scanner requires Node.js. 在技能目录用 PowerShell 运行，深度扫描脚本需要 Node.js。

```powershell
# Read-only C: report / C 盘只读盘点
.\scripts\cleanup-c-drive.ps1 -ReportOnly

# Known caches, retaining files modified within 7 days / 已知缓存，保留最近 7 天文件
.\scripts\cleanup-c-drive.ps1 -CleanKnownCaches

# Exact reviewed targets on any local drive / 任意本地磁盘的明确目标
.\scripts\cleanup-targets.ps1 -TargetPath 'D:\ExampleApp\Cache' -OutputPath "$env:USERPROFILE\cleanup-preview.json"
.\scripts\cleanup-targets.ps1 -TargetPath 'D:\ExampleApp\Cache' -Apply -OutputPath "$env:USERPROFILE\cleanup-result.json"

# Authorized full removal of one installer file / 经授权完整删除一个安装包
.\scripts\cleanup-targets.ps1 -TargetPath 'D:\Staging\old-installer.zip' -Apply -MinimumAgeDays 0

# Review discovered candidates before passing their exact paths / 指定已审核的发现项
.\scripts\cleanup-c-drive.ps1 -CleanDiscoveredAppCaches -ApprovedAppCachePaths 'C:\Users\Example\AppData\Roaming\ExampleApp\Cache'

# Read-only deep scan with progress and access-error reporting / 带进度和访问错误的深度只读扫描
node .\scripts\audit-storage.cjs --output "$env:USERPROFILE\storage-audit.json" 'C:\Users\Example' 'D:\Projects'

# Isolated behavioral checks / 隔离环境行为检查
.\scripts\test-cleanup-targets.ps1
```

`cleanup-targets.ps1` defaults to preview. Deletion requires `-Apply`. It validates absolute local paths, rejects overlapping roots and linked ancestors, skips child links, blocks running executables in target roots, and reports failures. Directory roots are preserved. It cannot detect every service/configuration dependency or prevent concurrent filesystem replacement; the agent must inspect usage and operate on quiescent targets.

`cleanup-targets.ps1` 默认预览，通过 `-Apply` 才删除。它校验绝对本地路径，拒绝重叠目标和带链接的上级路径，跳过子目录链接，检查目标中的运行程序，并报告失败。目标根目录会保留。脚本无法发现全部服务或配置依赖，也无法杜绝并发替换目录，因此 agent 仍需核对用途并在目录停止变更时执行。

Logical deleted bytes and net free-space change can differ because of hardlinks, compression and concurrent application writes. Permission-denied paths are incomplete measurements. Windows component maintenance uses official tools and can require elevation.

硬链接、压缩和运行中应用的写入会导致删除文件大小与实际可用空间变化不同。权限不足的路径属于未完整统计。Windows 系统组件维护使用官方工具，可能需要管理员权限。

More details / 更多说明

- [Skill instructions / 技能入口](SKILL.md)
- [Deep-cleanup decisions / 深度清理判断](references/deep-cleanup.md)
- [Safety policy / 清理边界](references/safety-policy.md)
