$Script:AppsOverview = [ordered] @{
    Name       = 'Apps Overview (Linked)'
    Enabled    = $false
    Execute    = {
        $appsDetail = if ($Script:GraphEssentialsAppsDetailLevel) { $Script:GraphEssentialsAppsDetailLevel } else { 'Full' }
        $appsType   = if ($Script:GraphEssentialsAppsApplicationType) { $Script:GraphEssentialsAppsApplicationType } else { 'All' }

        # Reuse data if Apps / AppsCredentials already ran
        $appsData = $null
        if ($Script:Reporting.Contains('Apps') -and $Script:Reporting['Apps'].Data) {
            $appsData = $Script:Reporting['Apps'].Data
        }
        if (-not $appsData) {
            $appsData = Get-MyApp -DetailLevel $appsDetail -ApplicationType $appsType
        }

        $credsData = $null
        if ($Script:Reporting.Contains('AppsCredentials') -and $Script:Reporting['AppsCredentials'].Data) {
            $credsData = $Script:Reporting['AppsCredentials'].Data
        }
        if (-not $credsData) {
            $credsData = Get-MyAppCredentials
        }

        [ordered]@{
            Apps        = $appsData
            Credentials = $credsData
        }
    }
    Processing = { }
    Summary    = { }
    Variables  = @{}
    Solution   = {
        Add-AppsOverviewContent -Applications $Script:Reporting['AppsOverview']['Data'].Apps -Credentials $Script:Reporting['AppsOverview']['Data'].Credentials -Version $Script:Reporting['Version'] -Embed
    }
}
