# Creates GitHub milestones issues from scripts/roadmap-issues.json
$ErrorActionPreference = "Stop"
$Repo = "mbx30/harpy"
$PlanUrl = "https://app.notion.com/p/3919cb079ddb8132ae08f16afdd9f0a0"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Issues = Get-Content (Join-Path $ScriptDir "roadmap-issues.json") -Raw | ConvertFrom-Json

foreach ($issue in $Issues) {
    $body = @"
$($issue.body)

---
**Milestone:** $($issue.milestone)
**Plan:** [$PlanUrl]($PlanUrl)
**Linear (reference):** https://linear.app/mbx2/project/harpy-16c5704dd57d/overview
"@

    $labelArgs = @()
    foreach ($label in $issue.labels) {
        $labelArgs += "--label"
        $labelArgs += $label
    }

    $url = gh issue create -R $Repo `
        --title $issue.title `
        --body $body `
        --milestone $issue.milestone `
        @labelArgs

    Write-Output "Created: $($issue.title) -> $url"
}

Write-Output "Done. Created $($Issues.Count) issues."
