function Get-MyDefenderSecureScore {
    <#
    .SYNOPSIS
    Retrieves Microsoft Defender secure score information.

    .DESCRIPTION
    Gets detailed information about Microsoft Defender secure scores from the Microsoft Graph Security API.
    Returns secure score metrics including current score, max score, and individual control scores.

    .PARAMETER IncludeScoreSummary
    When specified, includes a summary of the secure score metrics in the output.

    .PARAMETER All
    When specified, retrieves all historical secure scores instead of just the most recent one.

    .EXAMPLE
    Get-MyDefenderSecureScore
    Returns the most recent Microsoft Defender secure score details.

    .EXAMPLE
    Get-MyDefenderSecureScore -IncludeScoreSummary
    Returns the most recent Microsoft Defender secure score with a summary of metrics.

    .EXAMPLE
    Get-MyDefenderSecureScore -All
    Returns all historical Microsoft Defender secure scores.

    .NOTES
    This function requires the Microsoft.Graph.Beta.Security module and appropriate permissions.
    #>
    [cmdletbinding()]
    param(
        [switch] $IncludeScoreSummary,
        [switch] $All
    )
    if ($All) {
        try {
            Write-Verbose -Message 'Get-MyDefenderSecureScore - Getting all Secure Scores'
            $SecureScore = Get-MgBetaSecuritySecureScore -All -ErrorAction Stop
        } catch {
            Write-Warning -Message "Get-MyDefenderSecureScore - Unable to retrieve Secure Score. Error: $($_.Exception.Message)"
            return $false
        }
    } else {
        try {
            Write-Verbose -Message 'Get-MyDefenderSecureScore - Getting top 1 Secure Score'
            $SecureScore = Get-MgBetaSecuritySecureScore -Top 1 -ErrorAction Stop
        } catch {
            Write-Warning -Message "Get-MyDefenderSecureScore - Unable to retrieve Secure Score. Error: $($_.Exception.Message)"
            return $false
        }
    }
    try {
        $ScoreList = Get-MyDefenderSecureScoreProfile -AsHashtable -ErrorAction Stop
    } catch {
        Write-Warning -Message "Get-MyDefenderSecureScore - Unable to retrieve Secure Score Profile. Error: $($_.Exception.Message)"
        $ScoreList = @{}
    }
    $Properties = [ordered]@{
        'on'                   = $true
        'lastSynced'           = $true
        'implementationStatus' = $true
        'scoreInPercentage'    = $true
        'count'                = $true
        'total'                = $true
        'state'                = $true
    }

    foreach ($Score in $SecureScore) {
        $ScoreSummary = @{
            'ActiveUserCount'   = $Score.ActiveUserCount
            'AverageScore'      = $Score.AverageComparativeScores | Where-Object { $_.Basis -eq 'AllTenants' } | Select-Object -ExpandProperty AverageScore
            'AzureTenantId'     = $Score.AzureTenantId
            'CreatedDateTime'   = $Score.CreatedDateTime
            'CurrentScore'      = $Score.CurrentScore
            'EnabledServices'   = $Score.EnabledServices
            'Id'                = $Score.Id
            'LicensedUserCount' = $Score.LicensedUserCount
            'MaxScore'          = $Score.MaxScore
            'VendorInformation' = $Score.VendorInformation
        }
        $List = $Score.ControlScores | ForEach-Object {
            $Control = [ordered]@{
                ControlCategory = $_.ControlCategory
                ControlName     = $_.ControlName
                Description     = $_.Description
                Score           = $_.Score
            }
            foreach ($Property in $Properties.Keys) {
                $Control[$Property] = $_.AdditionalProperties[$Property]
            }
            foreach ($Property in $_.AdditionalProperties.Keys) {
                if ($Properties[$Property]) {
                    continue
                }
                Write-Warning -Message "Get-MyDefenderSecureScore - Additional property '$Property' found in control '$($_.ControlName)'. Please update the script to include this property."
                $Control[$Property] = $_.AdditionalProperties[$Property]
            }
            if ($ScoreList[$_.ControlName]) {
                $ControlData = $ScoreList[$_.ControlName]
                foreach ($Property in $ControlData.PSObject.Properties.Name) {
                    $Control[$Property] = $ControlData.$Property
                }
            } else {
                Write-Warning -Message "Get-MyDefenderSecureScore - Control '$($_.ControlName)' not found in profile. Please update the script to include this control."
            }

            [PSCustomObject]$Control
        }
        if ($IncludeScoreSummary) {
            [ordered] @{
                SecureScoreSummary = [PSCustomObject]$ScoreSummary
                SecureScoreList    = $List
            }
        } else {
            $List
        }
    }
}