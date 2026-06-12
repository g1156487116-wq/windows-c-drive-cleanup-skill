# Windows C Drive Cleanup Skill / Windows C 盘清理 Skill

## English

This is a Codex skill for safely inspecting and cleaning Windows `C:` drive space.
It is designed for cautious cleanup: diagnose first, delete only clearly regenerable caches, then report what changed.

### What It Does

- Inventories `C:` free space and common cleanup candidates.
- Cleans low-risk temporary files and cache directories when explicitly requested.
- Reports reclaimed space after cleanup.
- Leaves personal files and higher-risk system settings alone unless the user explicitly approves them.

### Safe Cleanup Targets

- User and Windows temporary files.
- Edge and Chrome cache directories.
- Electron/WebView app caches after review.
- NVIDIA shader/update caches.
- Steam `htmlcache`.
- Crash dump files when not actively needed for debugging.

### What It Avoids by Default

- Desktop, Documents, Downloads, Pictures, Videos, and Music.
- App data roots such as WeChat/Tencent, WPS/kingsoft, Adobe, Steam, Lark, or NetEase.
- `C:\ProgramData\Package Cache`.
- System restore points, hibernation, pagefile settings, registry cleanup, and third-party cleaner behavior.

### Install

Clone this repository into your Codex skills directory:

```powershell
cd $env:USERPROFILE\.codex\skills
git clone https://github.com/g1156487116-wq/windows-c-drive-cleanup-skill.git windows-c-drive-cleanup
```

Restart Codex if needed so the skill is discovered.

### Use

After installing, you can simply tell your agent:

```text
Clean my C drive
```

or in Chinese:

```text
清理C盘
```

For explicit invocation:

```text
Use $windows-c-drive-cleanup to inspect C drive usage, clean safe caches, and report reclaimed space.
```

The agent should first run a read-only inventory, explain the cleanup candidates, then clean safe caches and report the before/after free space.

### Manual Script Usage

Read-only report:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\cleanup-c-drive.ps1 -ReportOnly
```

Clean known safe caches:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\cleanup-c-drive.ps1 -CleanKnownCaches
```

Clean known safe caches plus reviewed app cache candidates:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\cleanup-c-drive.ps1 -CleanKnownCaches -CleanDiscoveredAppCaches
```

## 中文

这是一个用于安全检查和清理 Windows `C:` 盘空间的 Codex skill。
它的原则是：先诊断，再删除；只清理明确可再生的缓存，最后报告释放了多少空间。

### 它能做什么

- 盘点 `C:` 盘剩余空间和常见清理候选项。
- 在明确需要清理时，删除低风险临时文件和缓存目录。
- 清理后报告释放空间。
- 默认不碰个人文件和高风险系统设置，除非用户明确批准。

### 默认可清理目标

- 用户临时文件和 Windows 临时文件。
- Edge、Chrome 浏览器缓存。
- 经过确认的 Electron/WebView 应用缓存。
- NVIDIA 着色器缓存和更新包缓存。
- Steam `htmlcache`。
- 不再需要调试时的崩溃转储文件。

### 默认不会清理

- 桌面、文档、下载、图片、视频、音乐。
- 微信/Tencent、WPS/kingsoft、Adobe、Steam、飞书、网易云等应用主数据目录。
- `C:\ProgramData\Package Cache`。
- 系统还原点、休眠、虚拟内存设置、注册表清理、第三方清理软件式的一键清理。

### 安装

把这个仓库克隆到 Codex skills 目录：

```powershell
cd $env:USERPROFILE\.codex\skills
git clone https://github.com/g1156487116-wq/windows-c-drive-cleanup-skill.git windows-c-drive-cleanup
```

如有需要，重启 Codex，让它重新发现这个 skill。

### 使用

安装后，你可以直接对 agent 说：

```text
清理C盘
```

或者：

```text
Clean my C drive
```

也可以显式调用：

```text
Use $windows-c-drive-cleanup to inspect C drive usage, clean safe caches, and report reclaimed space.
```

agent 应该先进行只读盘点，解释哪些能清、哪些不能自动动，然后清理安全缓存，并报告清理前后的 C 盘可用空间。

### 手动运行脚本

只读盘点：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\cleanup-c-drive.ps1 -ReportOnly
```

清理已知安全缓存：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\cleanup-c-drive.ps1 -CleanKnownCaches
```

清理已知安全缓存，并清理已经确认的应用缓存候选项：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\cleanup-c-drive.ps1 -CleanKnownCaches -CleanDiscoveredAppCaches
```

## Disclaimer / 免责声明

Review the report before deleting anything beyond known cache targets. This skill is intentionally conservative and does not replace backups or Windows system administration judgment.

清理已知缓存之外的内容前，请先阅读报告并确认风险。这个 skill 默认偏谨慎，不能替代备份和 Windows 系统维护判断。
