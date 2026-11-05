# Deep cleanup decisions

Record each candidate's absolute path, logical size, owner, last modification, evidence of purpose, active references, and deletion conditions. Deduplicate nested roots before summing. Hardlinked files can contribute logical bytes without releasing the same amount of storage.

| Class | Evidence and action |
| --- | --- |
| Installer/download staging | Confirm archives or extracted setup files, successful installation elsewhere, and no installer using the staging location. Hash equal-size files before claiming duplicates. A runtime download archive can be disposable while the installed runtime is active. |
| Extracted software copy | Compare executable version/hash and directory layout with the deployed copy. Check services, shortcuts, tasks and launch arguments. Data/configuration need separate scope approval. |
| Crash dumps | Confirm ownership and date. Remove when the user no longer needs that diagnostic incident; elevated files can remain inaccessible. |
| Logs | Inspect types and timestamps. Logs can contain audit evidence. Retain recent/live files unless the user approved the exact batch. Database binlogs and transaction logs require database-native retention procedures. |
| Dependency copies | Verify a failed/stale install or retired environment. Keep source, lockfiles and custom patches. Prefer package-manager cleanup for shared stores; hardlinks affect space estimates. |
| Browser/app models | Identify the model and affected features. Explain loss of offline capability and possible re-download. Avoid changing security/privacy settings to prevent downloads. |
| Old application versions | Inspect launcher config, executable paths, shortcuts and uninstall entries. Validate the retained version after any reversible launcher change. Use an official uninstaller for whole-app removal. |
| Agent state | Distinguish download archives and runtimes from conversations, session databases, providers and working files. Explicit user exclusions persist. |
| Backups and releases | Identify restore points and deployed versions before retention pruning. "Backup" or "quarantine" does not establish disposability. Approval of all listed backups applies only to those exact listed roots. |
| Media caches | Establish the owning app and file format. Download directories can contain original media; editor proxies, AI materials and prerenders may support projects. Treat them as conditional candidates. |

## Execution

- Preview exact targets with `cleanup-targets.ps1`. File targets suit archives and dumps. Set `-MinimumAgeDays 0` only for reviewed full removal.
- Directory actions remove contents while preserving the root. Child reparse points are skipped and reported. Review leftovers rather than broadening deletion to parent folders.
- Carry forward authorization. Do not ask again for every file in an approved batch. Ask only when a newly discovered action changes the approved scope.
- Detect active processes, services and referenced environments. Back up configuration changes and validate the retained entry point. Disclose any startup changes in the final report.
- For uninstalls, inspect supported arguments or use the installed uninstaller UI. Do not guess silent flags. Record residual data and failed deletions separately from successful uninstallation.
- Save previews, per-target results and free-space snapshots outside the repository. The target script checkpoints after each finished target with `Complete=false`, then writes `Complete=true` and the final drive snapshot. An interrupted target is not included in that checkpoint. Recheck remaining bytes and file counts; enumeration failures are incomplete measurements.

## Official maintenance interfaces

- [uv cache management](https://docs.astral.sh/uv/concepts/cache/) provides `uv cache clean` and `uv cache prune`; manually removing individual entries can violate cache coordination.
- [pnpm store management](https://pnpm.io/cli/store) provides `pnpm store prune`; inspect the installed version and actual store path first.
- [Chrome model management](https://developer.chrome.com/docs/ai/understand-built-in-model-management) documents downloads and purges. Models may be downloaded again when a feature needs them.
- [Windows component cleanup](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/clean-up-the-winsxs-folder) documents DISM. Analyze first, and require the user's decision about update rollback before `/ResetBase`.
