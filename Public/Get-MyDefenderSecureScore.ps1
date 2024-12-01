﻿function Get-MyDefenderSecureScore {
    [cmdletbinding()]
    param(
        [switch] $IncludeScoreSummary,
        [switch] $All
    )
    if ($All) {
        Write-Verbose -Message 'Get-MyDefenderSecureScore - Getting all Secure Scores'
        $SecureScore = Get-MgBetaSecuritySecureScore -All
    } else {
        Write-Verbose -Message 'Get-MyDefenderSecureScore - Getting top 1 Secure Score'
        $SecureScore = Get-MgBetaSecuritySecureScore -Top 1
    }

    $ScoreList = Get-MyDefenderSecureScoreProfile -AsHashtable

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