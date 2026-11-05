---
name: windows-c-drive-cleanup
description: "Inspect and clean Windows C: or multiple local drives, including regenerable caches, installer leftovers, old logs, and reviewed deep-cleanup candidates. Use for disk-space diagnosis, routine cleanup, or a deeper storage audit."
---

# Windows Disk Cleanup

## Scope and authorization

Carry forward the user's approvals and exclusions. A request to inspect produces candidates; a request to clean authorizes known regenerable caches. Explicit approval of listed deep-cleanup candidates authorizes those exact targets without another confirmation. Clarify only a material ambiguity, such as whether "all" includes personal media mentioned outside the candidate list.

Discover current fixed drives with `Get-Volume` or `Win32_LogicalDisk`; never assume a particular drive layout. Recheck paths, ownership, timestamps, and running processes on every run. Historical sizes are clues, not current measurements. Do not start Docker or other services just to inventory storage.

## Routine cleanup

1. Run `scripts/cleanup-c-drive.ps1 -ReportOnly` for the C: baseline. For other drives, inspect known app locations and configured cache paths.
2. Review ownership and contents. A name containing `cache`, `log`, `temp`, or `backup` does not establish disposability. MSIX `LocalCache` can contain application state, and video-editor caches can contain materials or project dependencies.
3. Use `-CleanKnownCaches` for the built-in targets. Files modified within seven days are retained by default. Change the age threshold only when the target's purpose and the approved scope justify it.
4. Discovered candidates require an exact reviewed list with `-ApprovedAppCachePaths`; never bulk-delete all regex matches. Prefer `cleanup-targets.ps1` for multi-drive or individual-file cleanup.
5. Report deleted logical bytes separately from net free-space change, and disclose skipped/locked files and unreadable paths. Save reports outside the public skill repository.

```powershell
.\scripts\cleanup-targets.ps1 -TargetPath 'D:\ExampleApp\Cache' -OutputPath "$env:USERPROFILE\cleanup-preview.json"
.\scripts\cleanup-targets.ps1 -TargetPath 'D:\ExampleApp\Cache' -Apply -OutputPath "$env:USERPROFILE\cleanup-result.json"
```

The target script is preview-only unless `-Apply` is provided. It validates literal absolute paths, rejects linked ancestors and overlapping targets, skips child links, checks executable locations, and verifies remaining files. It preserves the selected directory itself. Its process check cannot prove a folder is unused by interpreters, services, tasks or application configuration; inspect those references separately when relevant. Run deletion only while the target tree is quiescent; filesystem checks are not an atomic defense against concurrent directory replacement.

## Deep audit

Read [references/deep-cleanup.md](references/deep-cleanup.md) for installer archives, dumps, logs, copied dependencies, models, application versions, backups, and release artifacts.

Use the read-only scanner on selected roots after a top-level inventory. It emits progress, avoids directory links, and records access failures. Avoid repeatedly rescanning complete project trees.

```powershell
node .\scripts\audit-storage.cjs --output "$env:USERPROFILE\storage-audit.json" 'C:\Users\Example' 'D:\Projects'
```

Group candidates by ownership and deletion conditions. Hash suspected duplicates before claiming identical contents. Folder size is not a reclaimed-space promise, especially with hardlinks, compression, sparse files, or nested candidates. With explicit approval, convert the reviewed list to exact paths and execute batches with JSON reports.

## Boundaries

Personal media, chat records, source code, database state, agent histories and recovery backups require explicit scope approval. Preserve session databases and provider-switching state according to the user's decisions. Do not generalize one user's permission to other machines.

Use an application's official uninstaller for whole-app removal. Verify completion, registration, active processes, and leftover paths. For old versions, check launcher configuration, shortcuts and uninstall registrations; a numerically older folder can still be the launch target. Back up changed launcher configuration and validate the retained version before deleting the old one. Restore the configuration if validation fails.

Do not force locked files, take ownership, change ACLs, disable security, or treat access-denied scans as empty directories. Use official Windows maintenance tools for component-store cleanup, and report when elevation prevents analysis. Hibernation, pagefiles, restore points, cloud sync, and migrations require the corresponding user decision.

Read [references/safety-policy.md](references/safety-policy.md) for additional system and application boundaries. Keep machine-specific paths, hashes, logs, screenshots and reports out of published skills.
