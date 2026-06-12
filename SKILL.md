---
name: windows-c-drive-cleanup
description: "Safely inspect and clean Windows C drive space. Use when the user asks to clean C:, free disk space, diagnose why C: is filling up, apply a Windows/CSDN C-drive cleanup guide, remove temporary files, browser/app caches, Windows Update or Delivery Optimization caches, NVIDIA cache/update artifacts, or report reclaimed space without deleting personal data."
---

# Windows C Drive Cleanup

## Workflow

Treat cleanup as diagnosis first, deletion second.

1. Read the user's source guide or article when one is provided. If using online or time-sensitive Windows guidance, verify with current official sources before applying it.
2. Run a read-only inventory first:

```powershell
.\scripts\cleanup-c-drive.ps1 -ReportOnly
```

3. Explain the largest candidates by ownership and risk. Separate:
   - safe regenerable caches,
   - personal files or application data,
   - admin-sensitive system items,
   - items that should not be deleted automatically.
4. Clean only clearly regenerable caches unless the user explicitly approves more:

```powershell
.\scripts\cleanup-c-drive.ps1 -CleanKnownCaches
```

5. If the inventory shows large discovered Electron/WebView/app cache directories, clean them only after confirming they are cache-like paths:

```powershell
.\scripts\cleanup-c-drive.ps1 -CleanKnownCaches -CleanDiscoveredAppCaches
```

6. Re-run the report and state before/after C: free space plus what was intentionally left alone.

## Safety Rules

- Do not delete user folders such as Desktop, Documents, Downloads, Pictures, Videos, or Music automatically.
- Do not delete whole AppData vendor folders such as Tencent, WeChat, WPS/kingsoft, LarkShell, NetEase, Adobe, or Steam. Delete only cache subdirectories after ownership is understood.
- Do not delete `C:\ProgramData\Package Cache`; it can affect repair, update, or uninstall flows.
- Do not force-delete locked files. Leave active files for later and report that they were skipped.
- Do not change pagefile, hibernation, restore points, compression, OneDrive, or default save locations unless the user explicitly asks for those tradeoffs.
- Prefer moving regenerable caches off C: for recurring growth when a stable alternate drive exists, but first verify the current environment variables and app settings.

## Known Good Targets

The script includes these low-risk classes:

- `%TEMP%`, `C:\Windows\Temp`
- Windows Update download cache and Delivery Optimization cache
- Browser `Cache`, `Code Cache`, `GPUCache`, and `Service Worker\CacheStorage` for Edge and Chrome default profiles
- NVIDIA `DXCache`, `GLCache`, and NVIDIA app `UpdateFramework\ota-artifacts`
- Steam `htmlcache`
- Windows user `CrashDumps`

Discovered app caches are limited to directories whose names match cache/temp/log/crash patterns under user AppData. Review the report before using `-CleanDiscoveredAppCaches`.

## References

- Read `references/safety-policy.md` when the user asks for broader cleanup, system restore/hibernation/pagefile changes, or deletion outside the built-in script targets.
- Use `scripts/cleanup-c-drive.ps1` for repeatable inventory and safe cleanup.
