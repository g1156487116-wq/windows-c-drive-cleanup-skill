param(
  [switch]$ReportOnly,
  [switch]$CleanKnownCaches,
  [switch]$CleanDiscoveredAppCaches,
  [int]$MinimumCandidateMB = 50
)

$ErrorActionPreference = 'SilentlyContinue'

function Format-Bytes([double]$Bytes) {
  if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
  if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
  if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
  return ('{0:N0} B' -f $Bytes)
}

function Get-DirBytes([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return 0 }
  $sum = (Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction SilentlyContinue |
    Measure-Object -Property Length -Sum).Sum
  if ($null -eq $sum) { return 0 }
  return [double]$sum
}

function Get-DriveSnapshot {
  $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
  [pscustomobject]@{
    Drive = 'C:'
    Size = Format-Bytes $drive.Size
    Free = Format-Bytes $drive.FreeSpace
    Used = Format-Bytes ($drive.Size - $drive.FreeSpace)
    FreePercent = ('{0:N1}%' -f (($drive.FreeSpace / $drive.Size) * 100))
    FreeBytes = [double]$drive.FreeSpace
  }
}

function New-Target([string]$Name, [string]$Path, [string]$Class, [bool]$KnownSafe) {
  [pscustomobject]@{
    Name = $Name
    Path = $Path
    Class = $Class
    KnownSafe = $KnownSafe
    Bytes = Get-DirBytes $Path
  }
}

function Clear-Target([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Get-KnownTargets {
  $local = $env:LOCALAPPDATA
  $user = $env:USERPROFILE
  $targets = @(
    New-Target 'User temp' $env:TEMP 'temp' $true
    New-Target 'Windows temp' 'C:\Windows\Temp' 'temp' $true
    New-Target 'Windows Update download cache' 'C:\Windows\SoftwareDistribution\Download' 'windows-update-cache' $true
    New-Target 'Delivery Optimization cache' 'C:\ProgramData\Microsoft\Windows\DeliveryOptimization\Cache' 'windows-delivery-cache' $true
    New-Target 'Edge Cache' (Join-Path $local 'Microsoft\Edge\User Data\Default\Cache') 'browser-cache' $true
    New-Target 'Edge Code Cache' (Join-Path $local 'Microsoft\Edge\User Data\Default\Code Cache') 'browser-cache' $true
    New-Target 'Edge GPUCache' (Join-Path $local 'Microsoft\Edge\User Data\Default\GPUCache') 'browser-cache' $true
    New-Target 'Edge Service Worker CacheStorage' (Join-Path $local 'Microsoft\Edge\User Data\Default\Service Worker\CacheStorage') 'browser-cache' $true
    New-Target 'Chrome Cache' (Join-Path $local 'Google\Chrome\User Data\Default\Cache') 'browser-cache' $true
    New-Target 'Chrome Code Cache' (Join-Path $local 'Google\Chrome\User Data\Default\Code Cache') 'browser-cache' $true
    New-Target 'Chrome GPUCache' (Join-Path $local 'Google\Chrome\User Data\Default\GPUCache') 'browser-cache' $true
    New-Target 'Chrome Service Worker CacheStorage' (Join-Path $local 'Google\Chrome\User Data\Default\Service Worker\CacheStorage') 'browser-cache' $true
    New-Target 'NVIDIA DXCache' (Join-Path $local 'NVIDIA\DXCache') 'graphics-cache' $true
    New-Target 'NVIDIA GLCache' (Join-Path $local 'NVIDIA\GLCache') 'graphics-cache' $true
    New-Target 'NVIDIA app OTA artifacts' 'C:\ProgramData\NVIDIA Corporation\NVIDIA app\UpdateFramework\ota-artifacts' 'updater-cache' $true
    New-Target 'Steam htmlcache' (Join-Path $local 'Steam\htmlcache') 'app-cache' $true
    New-Target 'User CrashDumps' (Join-Path $local 'CrashDumps') 'crash-dumps' $true
  )
  $targets | Where-Object { $_.Path -and (Test-Path -LiteralPath $_.Path) }
}

function Get-DiscoveredAppCacheTargets {
  $roots = @(
    (Join-Path $env:USERPROFILE 'AppData\Local'),
    (Join-Path $env:USERPROFILE 'AppData\Roaming')
  )
  $namePattern = '^(Cache|Code Cache|GPUCache|DawnCache|ShaderCache|blob_storage|logs?|Temp|tmp|Crashpad|CrashDumps|INetCache|DXCache|GLCache|CacheStorage)$|cache|temp|tmp|log|crash'
  foreach ($root in $roots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    Get-ChildItem -LiteralPath $root -Force -Directory -Recurse -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match $namePattern } |
      ForEach-Object {
        $bytes = Get-DirBytes $_.FullName
        if ($bytes -ge ($MinimumCandidateMB * 1MB)) {
          [pscustomobject]@{
            Name = $_.Name
            Path = $_.FullName
            Class = 'discovered-app-cache'
            KnownSafe = $false
            Bytes = $bytes
          }
        }
      }
  }
}

function Get-HighRiskSnapshot {
  $paths = @(
    (Join-Path $env:USERPROFILE 'Desktop'),
    (Join-Path $env:USERPROFILE 'Documents'),
    (Join-Path $env:USERPROFILE 'Downloads'),
    (Join-Path $env:USERPROFILE 'Pictures'),
    (Join-Path $env:USERPROFILE 'Videos'),
    (Join-Path $env:APPDATA 'Tencent'),
    (Join-Path $env:APPDATA 'kingsoft'),
    'C:\ProgramData\Package Cache'
  )
  foreach ($path in $paths) {
    if (Test-Path -LiteralPath $path) {
      [pscustomobject]@{
        Path = $path
        Bytes = Get-DirBytes $path
      }
    }
  }
}

$before = Get-DriveSnapshot
$known = @(Get-KnownTargets)
$discovered = @(Get-DiscoveredAppCacheTargets)

if ($CleanKnownCaches -and -not $ReportOnly) {
  foreach ($target in $known) {
    Clear-Target $target.Path
  }
}

if ($CleanDiscoveredAppCaches -and -not $ReportOnly) {
  foreach ($target in $discovered) {
    Clear-Target $target.Path
  }
}

$after = Get-DriveSnapshot
$knownAfter = @(Get-KnownTargets)
$highRisk = @(Get-HighRiskSnapshot)

Write-Output '=== C drive ==='
$before | Select-Object Drive,Size,Free,Used,FreePercent | Format-List
if (($CleanKnownCaches -or $CleanDiscoveredAppCaches) -and -not $ReportOnly) {
  Write-Output '=== C drive after cleanup ==='
  $after | Select-Object Drive,Size,Free,Used,FreePercent,@{n='Freed';e={Format-Bytes ($after.FreeBytes - $before.FreeBytes)}} | Format-List
}

Write-Output '=== Known safe cache targets ==='
$known | Sort-Object Bytes -Descending |
  Select-Object Name,Class,@{n='Size';e={Format-Bytes $_.Bytes}},Path |
  Format-Table -AutoSize -Wrap

if ($CleanKnownCaches -and -not $ReportOnly) {
  Write-Output '=== Known safe cache targets after cleanup ==='
  $knownAfter | Sort-Object Bytes -Descending |
    Select-Object Name,Class,@{n='Size';e={Format-Bytes $_.Bytes}},Path |
    Format-Table -AutoSize -Wrap
}

Write-Output '=== Discovered app cache candidates, review before cleaning ==='
$discovered | Sort-Object Bytes -Descending |
  Select-Object @{n='Size';e={Format-Bytes $_.Bytes}},Path |
  Format-Table -AutoSize -Wrap

Write-Output '=== High-risk large locations, do not auto-delete ==='
$highRisk | Sort-Object Bytes -Descending |
  Select-Object @{n='Size';e={Format-Bytes $_.Bytes}},Path |
  Format-Table -AutoSize -Wrap

Write-Output '=== Pagefile and sleep files ==='
Get-CimInstance Win32_PageFileSetting | Select-Object Name,InitialSize,MaximumSize | Format-Table -AutoSize
Get-ChildItem -LiteralPath C:\ -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -in @('hiberfil.sys','pagefile.sys','swapfile.sys') } |
  Select-Object FullName,@{n='Size';e={Format-Bytes $_.Length}} |
  Format-Table -AutoSize

Write-Output '=== Shadow storage check ==='
vssadmin list shadowstorage 2>&1 | Select-Object -First 20

exit 0
