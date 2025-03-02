function Get-MyDefenderSummary {
    <#
    .SYNOPSIS
    Provides a summary of Microsoft Defender for Identity health issues.

    .DESCRIPTION
    Collects and categorizes Microsoft Defender for Identity health issues into global issues and sensor-specific issues.
    This function helps administrators quickly identify and prioritize health issues affecting their MDI deployment.

    .EXAMPLE
    Get-MyDefenderSummary
    Returns a summary object containing global and sensor-specific health issues from Microsoft Defender for Identity.

    .NOTES
    This function requires the Microsoft.Graph.Beta.Security module and appropriate permissions.
    Depends on Get-MyDefenderHealthIssues function to retrieve the underlying data.
    #>
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