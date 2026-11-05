# Safety Policy

## Evidence Sources

- Prefer Microsoft Storage Sense, Cleanup recommendations, and Disk Cleanup guidance for Windows-owned temporary files and system cleanup categories.
- User-supplied guides, including CSDN cleanup articles, can be used as checklists, but apply them through local inventory and risk classification.
- Browser caches, Electron/WebView app caches, NVIDIA update/shader caches, Steam cache, and `%TEMP%` are common candidates; verify their current contents and ownership.

## Risk Classes

Safe to clean after inventory:
- User and Windows temporary files.
- Browser and Electron/WebView cache directories named `Cache`, `Code Cache`, `GPUCache`, or `Service Worker\CacheStorage`.
- NVIDIA `DXCache`, `GLCache`, and `UpdateFramework\ota-artifacts`.
- Steam `htmlcache`.
- Crash dump files when the user is not actively debugging those crashes.

Require scope approval (carry forward an existing explicit decision):
- Desktop, Documents, Downloads, Pictures, Videos, Music.
- App vendor roots such as Tencent, WeChat, kingsoft/WPS, LarkShell, Adobe, NetEase, Steam, Docker, OpenAI, Codex.
- System restore points and shadow storage.
- Hibernation (`hiberfil.sys`) or pagefile settings.
- Moving user libraries or app cache locations to another drive.

Avoid by default:
- `C:\Windows` except documented temp/update-cache subdirectories.
- `C:\Program Files`, `C:\Program Files (x86)`, and `C:\ProgramData\Package Cache`.
- Registry cleanup and third-party "one-click cleaner" behavior.

## Reporting Standard

Always report:
- Before/after free space for each affected drive.
- Deleted logical bytes and measured net free-space change separately.
- Largest directories cleaned.
- Large directories intentionally left untouched and why.
- Any admin-only checks that could not be run, such as shadow storage.
- Access failures, skipped links, locked files, and any changed startup configuration.
