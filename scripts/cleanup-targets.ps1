param(
  [Parameter(Mandatory=$true)][string[]]$TargetPath,
  [switch]$Apply,
  [ValidateRange(0,36500)][int]$MinimumAgeDays = 7,
  [string]$OutputPath
)
$ErrorActionPreference = 'Stop'

function Assert-LocalTarget([string]$Path) {
  if ($Path -notmatch '^[A-Za-z]:\\') { throw "An absolute local path is required: $Path" }
  $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
  if ($full.Length -le 3) { throw "Drive roots are not cleanup targets: $full" }
  $probe = $full
  while ($probe) {
    $attributes = $null
    try { $attributes = [IO.File]::GetAttributes($probe) }
    catch [IO.FileNotFoundException] { }
    catch [IO.DirectoryNotFoundException] { }
    if ($null -ne $attributes -and ($attributes -band [IO.FileAttributes]::ReparsePoint)) {
      throw "Linked target or ancestor: $probe"
    }
    $probe = [IO.Path]::GetDirectoryName($probe)
  }
  $full
}

function Read-TargetTree([string]$Root) {
  $files = [Collections.Generic.List[object]]::new()
  $directories = [Collections.Generic.List[string]]::new()
  $issues = [Collections.Generic.List[string]]::new()
  if (-not (Test-Path -LiteralPath $Root)) {
    return [pscustomobject]@{Files=$files;Directories=$directories;Issues=$issues;Exists=$false}
  }
  $rootItem = Get-Item -LiteralPath $Root -Force
  if (-not $rootItem.PSIsContainer) { $files.Add($rootItem) }
  else {
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($Root)
    while ($pending.Count) {
      $directory = $pending.Pop()
      $directories.Add($directory)
      try { $entries = @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) }
      catch { $issues.Add("$directory : $($_.Exception.Message)"); continue }
      foreach ($entry in $entries) {
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
          $issues.Add("Skipped link: $($entry.FullName)")
        } elseif ($entry.PSIsContainer) { $pending.Push($entry.FullName) }
        else { $files.Add($entry) }
      }
    }
  }
  [pscustomobject]@{Files=$files;Directories=$directories;Issues=$issues;Exists=$true}
}

# Validate every root before any mutation. Nested targets would double count files.
$roots = @($TargetPath | ForEach-Object { Assert-LocalTarget $_ } | Select-Object -Unique)
if ($OutputPath) {
  $reportPath = Assert-LocalTarget ($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath))
  foreach ($root in $roots) {
    if ($reportPath -eq $root -or $reportPath.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Save the report outside cleanup targets'
    }
  }
}
foreach ($root in $roots) {
  foreach ($other in $roots) {
    if ($root.StartsWith($other + '\', [StringComparison]::OrdinalIgnoreCase)) {
      throw "Overlapping targets: $root and $other"
    }
  }
}
$processes = @(Get-CimInstance Win32_Process -ErrorAction Stop)
if ($Apply) {
  foreach ($root in $roots) {
    foreach ($process in $processes) {
      if ($process.ExecutablePath -and ($process.ExecutablePath.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or $process.ExecutablePath.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase))) {
        throw "Target contains running executable, PID $($process.ProcessId): $root"
      }
    }
  }
}
$letters = @($roots | ForEach-Object { $_.Substring(0,1) } | Select-Object -Unique)
function Read-FreeSpace {
  @(Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DeviceID.Substring(0,1) -in $letters } | Select-Object DeviceID,FreeSpace,Size)
}
$beforeDrives = Read-FreeSpace
$cutoff = (Get-Date).AddDays(-$MinimumAgeDays)
$results = [Collections.Generic.List[object]]::new()
foreach ($root in $roots) {
  Write-Host "Inspecting $root"
  $before = Read-TargetTree $root
  $eligible = @($before.Files | Where-Object LastWriteTime -LT $cutoff)
  [long]$deletedBytes = 0
  $deletedFiles = 0
  $alreadyMissing = 0
  $failures = [Collections.Generic.List[string]]::new()
  if ($Apply) {
    Write-Host "Deleting $($eligible.Count) eligible files in $root"
    $processed = 0
    foreach ($file in $eligible) {
      try {
        # Recheck ancestry and metadata immediately before deleting a literal file.
        $validated = Assert-LocalTarget $file.FullName
        if ($validated -ne $root -and -not $validated.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Path escaped target' }
        $current = Get-Item -LiteralPath $validated -Force
        if ($current.PSIsContainer -or $current.LastWriteTime -ge $cutoff) { continue }
        $length = $current.Length
        Remove-Item -LiteralPath $validated -Force -ErrorAction Stop
        $deletedBytes += $length
        $deletedFiles++
      } catch [System.Management.Automation.ItemNotFoundException] { $alreadyMissing++ }
      catch { $failures.Add("$($file.FullName) : $($_.Exception.Message)") }
      finally {
        $processed++
        if ($processed % 1000 -eq 0) { Write-Host "Processed $processed / $($eligible.Count) files in $root" }
      }
    }
    Write-Host "Removing empty child directories in $root"
    foreach ($directory in ($before.Directories | Sort-Object Length -Descending)) {
      if ($directory -eq $root) { continue }
      try {
        $null = Assert-LocalTarget $directory
        if (@(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop).Count -eq 0) {
          Remove-Item -LiteralPath $directory -Force -ErrorAction Stop
        }
      } catch [System.Management.Automation.ItemNotFoundException] { }
      catch { $failures.Add("$directory : $($_.Exception.Message)") }
    }
  }
  $after = if ($Apply) { Read-TargetTree $root } else { $before }
  $results.Add([pscustomobject]@{
    Path=$root; Exists=$before.Exists
    BeforeBytes=($before.Files | Measure-Object Length -Sum).Sum
    EligibleBytes=($eligible | Measure-Object Length -Sum).Sum
    DeletedBytes=$deletedBytes; DeletedFiles=$deletedFiles
    AlreadyMissingFiles=$alreadyMissing
    RemainingBytes=($after.Files | Measure-Object Length -Sum).Sum
    RemainingFiles=$after.Files.Count
    EnumerationIssues=@($before.Issues.ToArray()) + @($after.Issues.ToArray())
    Failures=@($failures.ToArray())
  })
  if ($OutputPath) {
    [pscustomobject]@{Timestamp=(Get-Date).ToString('o');Applied=[bool]$Apply;Complete=$false;MinimumAgeDays=$MinimumAgeDays;BeforeDrives=$beforeDrives;Targets=@($results.ToArray())} |
      ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $reportPath -Encoding UTF8
  }
  Write-Host "Finished $root ($deletedFiles files deleted)"
}
$report = [pscustomobject]@{Timestamp=(Get-Date).ToString('o');Applied=[bool]$Apply;Complete=$true;MinimumAgeDays=$MinimumAgeDays;BeforeDrives=$beforeDrives;AfterDrives=(Read-FreeSpace);Targets=@($results.ToArray())}
if ($OutputPath) { $report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $reportPath -Encoding UTF8 }
$report
