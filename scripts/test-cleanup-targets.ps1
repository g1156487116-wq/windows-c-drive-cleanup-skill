$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('cleanup-test-' + [guid]::NewGuid())
$outside = Join-Path $fixture 'outside'
$target = Join-Path $fixture 'target'
$null = New-Item -ItemType Directory -Path $outside,$target
$old = Join-Path $target 'old.txt'
$recent = Join-Path $target 'recent.txt'
$kept = Join-Path $outside 'keep.txt'
[IO.File]::WriteAllText($old,'old')
[IO.File]::WriteAllText($recent,'recent')
[IO.File]::WriteAllText($kept,'keep')
(Get-Item -LiteralPath $old).LastWriteTime = (Get-Date).AddDays(-30)
$link = Join-Path $target 'linked'
$null = New-Item -ItemType Junction -Path $link -Target $outside
$engine = Join-Path $PSScriptRoot 'cleanup-targets.ps1'
$preview = & $engine -TargetPath $target
if (-not (Test-Path -LiteralPath $old) -or $preview.Applied) { throw 'Preview mutated data' }
$reportPath = Join-Path $fixture 'result.json'
$result = & $engine -TargetPath $target -Apply -OutputPath $reportPath
$saved = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if (-not $saved.Complete -or $saved.Targets.Count -ne 1) { throw 'Final report incomplete' }
if ((Test-Path -LiteralPath $old) -or -not (Test-Path -LiteralPath $recent) -or -not (Test-Path -LiteralPath $kept)) { throw 'Age/link isolation failed' }
if ($result.Targets[0].DeletedBytes -ne 3) { throw 'Deleted byte accounting failed' }
$rejected = $false
try { & $engine -TargetPath $link -Apply | Out-Null } catch { $rejected = $true }
if (-not $rejected) { throw 'Linked root accepted' }
$rejected = $false
try { & $engine -TargetPath $fixture,$target -Apply | Out-Null } catch { $rejected = $true }
if (-not $rejected) { throw 'Overlapping roots accepted' }
$rejected = $false
try { & $engine -TargetPath $target -OutputPath (Join-Path $target 'report.json') -Apply | Out-Null } catch { $rejected = $true }
if (-not $rejected) { throw 'Report inside target accepted' }
$rejected = $false
Push-Location -LiteralPath $target
try { & $engine -TargetPath $target -OutputPath '.\recent.txt' | Out-Null } catch { $rejected = $true }
finally { Pop-Location }
if (-not $rejected -or [IO.File]::ReadAllText($recent) -ne 'recent') { throw 'Relative preview report overwrote target' }
$rejected = $false
try { & $engine -TargetPath $outside -OutputPath (Join-Path $link 'report.json') | Out-Null } catch { $rejected = $true }
if (-not $rejected) { throw 'Linked report path accepted' }
$rejected = $false
try { & $engine -TargetPath (Get-Process -Id $PID).Path -Apply | Out-Null } catch { $rejected = $true }
if (-not $rejected) { throw 'Running executable accepted' }
$rerun = & $engine -TargetPath $target -Apply
if ($rerun.Targets[0].DeletedFiles -ne 0) { throw 'Retry was not idempotent' }
# Exercise only the legacy wrapper, without scanning or cleaning real app caches.
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'cleanup-c-drive.ps1'), [ref]$null, [ref]$null)
$wrapper = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Clear-Target' }, $true)
$legacyScriptRoot = $PSScriptRoot
. ([scriptblock]::Create($wrapper.Extent.Text.Replace('$PSScriptRoot', '$legacyScriptRoot')))
$MinimumAgeDays = 7
$skipped = Clear-Target $link
if ($skipped.Status -ne 'Skipped') { throw 'Legacy wrapper did not record refused target' }
[IO.File]::WriteAllText($old,'old')
(Get-Item -LiteralPath $old).LastWriteTime = (Get-Date).AddDays(-30)
$continued = Clear-Target $target
if (Test-Path -LiteralPath $old) { throw 'Legacy wrapper did not continue with next target' }
# Remove the verified test junction before recursively removing this unique fixture.
[IO.Directory]::Delete($link)
$resolved = [IO.Path]::GetFullPath($fixture)
if (-not $resolved.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'cleanup-test-*') { throw 'Unsafe fixture cleanup' }
Remove-Item -LiteralPath $resolved -Recurse -Force
Write-Output 'PASS: preview, age filter, linked child/root, overlaps, absolute/relative report isolation, active executable, byte accounting, retry, legacy batch continuation'
