param(
  [int]$Batch = 200,
  [switch]$VerboseLog
)
$ErrorActionPreference = 'Stop'

Write-Host "Deleting ALL GitHub Actions runs across all workflows..."

# Show auth status for debugging
try {
  Write-Host "GH Auth Status:"
  gh auth status -h github.com
} catch {
  Write-Warning "gh auth status failed: $_"
}

# Newer gh versions removed -y from `gh run delete`; use REST API instead
function Remove-Run([string]$RunId) {
  if ([string]::IsNullOrWhiteSpace($RunId)) { return }
  if ($VerboseLog) { Write-Host ("Deleting run via REST: $RunId") }
  gh api -X DELETE "repos/${env:GITHUB_REPOSITORY}/actions/runs/$RunId" -H "Accept: application/vnd.github+json" 1>$null 2>$null
}

# Fallback when env var not set (local execution)
if (-not $env:GITHUB_REPOSITORY -or $env:GITHUB_REPOSITORY -eq '') {
  # Infer from git remote
  try {
    $remote = git remote get-url origin
    if ($remote -match 'github.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)') {
      $env:GITHUB_REPOSITORY = "$($Matches['owner'])/$($Matches['repo'])"
      Write-Host "GITHUB_REPOSITORY inferred as $($env:GITHUB_REPOSITORY)"
    }
  } catch {}
}

for ($loop = 0; $loop -lt 200; $loop++) {
  $runsJson = gh run list -L $Batch --json databaseId,status,workflowName,displayTitle 2>$null
  if (-not $runsJson) { Write-Host 'No workflow runs found.'; break }
  $runs = $runsJson | ConvertFrom-Json
  if (-not $runs -or $runs.Count -eq 0) { Write-Host 'No workflow runs found.'; break }

  Write-Host ("Batch: " + $runs.Count)
  foreach ($r in $runs) {
    $id = [string]$r.databaseId
    $status = [string]$r.status
    $wf = [string]$r.workflowName
    $title = [string]$r.displayTitle

    if ($VerboseLog) { Write-Host ("Processing $id ($wf - $title) status=$status") }

    try {
      if ($status -in @('in_progress','queued','waiting')) {
        Write-Host ("Cancelling $id ($wf - $title)...")
        gh run cancel $id 1>$null 2>$null
      }
    } catch { if ($VerboseLog) { Write-Warning $_ } }

    try {
      Remove-Run -RunId $id
    } catch { if ($VerboseLog) { Write-Warning $_ } }
  }
  Start-Sleep -Seconds 1
}

Write-Host 'Final check:'
$leftIds = gh run list -L 5 --json databaseId --jq '.[].databaseId' 2>$null
if (-not $leftIds -or $leftIds.Trim() -eq '') { Write-Host 'No workflow runs found.' } else { Write-Output $leftIds }

