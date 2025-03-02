function Get-MyDefenderSummary {
    [cmdletbinding()]
    param(

    )

    $DefenderHealthIssues = Get-MyDefenderHealthIssues -Status 'open'

    $ReportInformation = @{
        GlobalIssues = [System.Collections.Generic.List[PSCustomObject]]::new()
        SensorIssues = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    foreach ($Issue in $DefenderHealthIssues) {
        if ($Issue.HealthIssueType -eq 'sensor') {
            $ReportInformation.SensorIssues.Add($Issue)
        } else {
            $ReportInformation.GlobalIssues.Add($Issue)
        }
    }

    if ($Summary) {
        $CachedOutput = [ordered]@{}
        foreach ($Issue in $Output) {
            if (-not $CachedOutput[$Issue.DisplayName]) {
                $CachedOutput[$Issue.DisplayName] = [ordered] @{}
            }
            $CachedOutput[$Issue.DisplayName]

            if ($Issue.SensorDNSName) {
                $CachedOutput[$Issue.SensorDNSName]
            } else {

            }
        }
    } else {
        $Output
    }
}