function ConvertTo-MyConditionalAccessPivot {
    <#
    .SYNOPSIS
    Builds a pivot-style matrix from conditional access policy objects.

    .DESCRIPTION
    Converts conditional access policy objects into a row-per-attribute, column-per-policy
    matrix suitable for HTML reporting.

    .PARAMETER Policies
    The conditional access policy objects to pivot.

    .EXAMPLE
    ConvertTo-MyConditionalAccessPivot -Policies $CAData.Policies.All

    .NOTES
    Internal helper for Show-MyConditionalAccess.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject[]] $Policies
    )

    if (-not $Policies) {
        return
    }

    $RowDefinitions = [System.Collections.Generic.List[hashtable]]::new()
    $RowDefinitions.Add(@{ Name = 'Name'; Property = 'DisplayName' })
    $RowDefinitions.Add(@{ Name = 'PolicyID'; Property = 'Id' })
    $RowDefinitions.Add(@{ Name = 'Status'; Property = 'State' })
    $RowDefinitions.Add(@{ Name = 'Type'; Property = 'Type' })
    $RowDefinitions.Add(@{ Name = 'Users'; Property = $null })
    $RowDefinitions.Add(@{ Name = 'UsersInclude'; Property = 'UsersInclude' })
    $RowDefinitions.Add(@{ Name = 'UsersExclude'; Property = 'UsersExclude' })
    $RowDefinitions.Add(@{ Name = 'TargetResources'; Property = $null })
    $RowDefinitions.Add(@{ Name = 'ApplicationsIncluded'; Property = 'Applications' })
    $RowDefinitions.Add(@{ Name = 'ApplicationsExcluded'; Property = 'ApplicationsExcluded' })
    $RowDefinitions.Add(@{ Name = 'userActions'; Property = 'UserActions' })
    $RowDefinitions.Add(@{ Name = 'AuthContext'; Property = 'AuthContext' })
    $RowDefinitions.Add(@{ Name = 'Network'; Property = $null })
    $RowDefinitions.Add(@{ Name = 'LocationsIncluded'; Property = 'Locations' })
    $RowDefinitions.Add(@{ Name = 'LocationsExcluded'; Property = 'LocationsExcluded' })
    $RowDefinitions.Add(@{ Name = 'Conditions'; Property = $null })
    $RowDefinitions.Add(@{ Name = 'UserRisk'; Property = 'UserRiskLevels' })
    $RowDefinitions.Add(@{ Name = 'SignInRisk'; Property = 'SignInRiskLevels' })
    $RowDefinitions.Add(@{ Name = 'PlatformsInclude'; Property = 'Platforms' })
    $RowDefinitions.Add(@{ Name = 'PlatformsExclude'; Property = 'PlatformsExcluded' })
    $RowDefinitions.Add(@{ Name = 'ClientApps'; Property = 'ClientAppTypes' })
    $RowDefinitions.Add(@{ Name = 'Devices'; Property = $null })
    $RowDefinitions.Add(@{ Name = 'DevicesIncluded'; Property = 'DevicesIncluded' })
    $RowDefinitions.Add(@{ Name = 'DevicesExcluded'; Property = 'DevicesExcluded' })
    $RowDefinitions.Add(@{ Name = 'DeviceFilters'; Property = 'DeviceFilterRule' })
    $RowDefinitions.Add(@{ Name = 'DeviceFilterMode'; Property = 'DeviceFilterMode' })
    $RowDefinitions.Add(@{ Name = 'GrantControls'; Property = $null })
    $RowDefinitions.Add(@{ Name = 'BuiltInControls'; Property = 'GrantControls' })
    $RowDefinitions.Add(@{ Name = 'AuthStrength'; Property = 'AuthStrength' })
    $RowDefinitions.Add(@{ Name = 'TermsOfUse'; Property = 'GrantControlsTermsOfUse' })
    $RowDefinitions.Add(@{ Name = 'CustomControls'; Property = 'GrantControlsCustomControls' })
    $RowDefinitions.Add(@{ Name = 'GrantOperator'; Property = 'GrantControlsOperator' })
    $RowDefinitions.Add(@{ Name = 'SessionControls'; Property = $null })
    $RowDefinitions.Add(@{ Name = 'SessionControlsAdditionalProperties'; Property = 'SessionControlsAdditionalProperties' })
    $RowDefinitions.Add(@{ Name = 'ApplicationEnforcedRestrictionsIsEnabled'; Property = 'ApplicationEnforcedRestrictionsIsEnabled' })
    $RowDefinitions.Add(@{ Name = 'ApplicationEnforcedRestrictionsAdditionalProperties'; Property = 'ApplicationEnforcedRestrictionsAdditionalProperties' })
    $RowDefinitions.Add(@{ Name = 'CloudAppSecurityType'; Property = 'CloudAppSecurityType' })
    $RowDefinitions.Add(@{ Name = 'CloudAppSecurityIsEnabled'; Property = 'CloudAppSecurityIsEnabled' })
    $RowDefinitions.Add(@{ Name = 'CloudAppSecurityAdditionalProperties'; Property = 'CloudAppSecurityAdditionalProperties' })
    $RowDefinitions.Add(@{ Name = 'DisableResilienceDefaults'; Property = 'DisableResilienceDefaults' })
    $RowDefinitions.Add(@{ Name = 'PersistentBrowserIsEnabled'; Property = 'PersistentBrowserIsEnabled' })
    $RowDefinitions.Add(@{ Name = 'PersistentBrowserMode'; Property = 'PersistentBrowserMode' })
    $RowDefinitions.Add(@{ Name = 'PersistentBrowserAdditionalProperties'; Property = 'PersistentBrowserAdditionalProperties' })
    $RowDefinitions.Add(@{ Name = 'SignInFrequencyAuthenticationType'; Property = 'SignInFrequencyAuthenticationType' })
    $RowDefinitions.Add(@{ Name = 'SignInFrequencyInterval'; Property = 'SignInFrequencyInterval' })
    $RowDefinitions.Add(@{ Name = 'SignInFrequencyIsEnabled'; Property = 'SignInFrequencyIsEnabled' })
    $RowDefinitions.Add(@{ Name = 'SignInFrequencyType'; Property = 'SignInFrequencyType' })
    $RowDefinitions.Add(@{ Name = 'SignInFrequencyValue'; Property = 'SignInFrequencyValue' })
    $RowDefinitions.Add(@{ Name = 'SignInFrequencyAdditionalProperties'; Property = 'SignInFrequencyAdditionalProperties' })

    $PolicyColumns = [System.Collections.Generic.List[string]]::new()
    $PolicyIndex = 1
    foreach ($Policy in $Policies) {
        $PolicyColumns.Add("Policy $PolicyIndex")
        $PolicyIndex++
    }

    $PivotRows = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($Row in $RowDefinitions) {
        $RowData = [ordered]@{
            'CA Item' = $Row.Name
        }

        $PolicyIndex = 0
        foreach ($Policy in $Policies) {
            $PolicyIndex++
            $ColumnName = $PolicyColumns[$PolicyIndex - 1]

            $Value = $null
            if ($Row.ContainsKey('Property') -and $Row.Property) {
                $Value = $Policy.$($Row.Property)
            }

            $RowData[$ColumnName] = ConvertTo-MyDisplayString -Value $Value -ReturnEmptyStringForNull
        }

        $PivotRows.Add([PSCustomObject]$RowData)
    }

    $PivotRows
}
