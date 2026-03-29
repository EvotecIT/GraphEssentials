$Script:Apps = [ordered] @{
    Name       = 'Azure Active Directory Apps'
    Enabled    = $true
    Execute    = {
        $appsDetail = if ($Script:GraphEssentialsAppsDetailLevel) { $Script:GraphEssentialsAppsDetailLevel } else { 'Full' }
        $appsType = if ($Script:GraphEssentialsAppsApplicationType) { $Script:GraphEssentialsAppsApplicationType } else { 'All' }
        Get-MyApp -DetailLevel $appsDetail -ApplicationType $appsType
    }
    Processing = {

    }
    Summary    = {
        $appData = @($Script:Reporting['Apps']['Data'])
        $totalApps = $appData.Count
        $firstPartyApps = 0
        $microsoftApps = 0
        $thirdPartyApps = 0
        $managedIdentityApps = 0
        $delegatedPermissionApps = 0
        $applicationPermissionApps = 0
        $noPermissionApps = 0
        $inactiveApps = 0
        $recentApps = 0
        $staleApps = 0
        $appsWithCredentialInventory = 0
        $appsWithoutCredentialInventory = 0
        $appsWithOwnedCredentials = 0
        $appsWithoutOwnedCredentials = 0
        $appsWithExpiredOwnedCredentials = 0
        $sourceCounts = @{}
        $permissionCounts = @{}
        $activityCounts = @{
            'No activity observed' = 0
            '0-30 days'            = 0
            '31-90 days'           = 0
            '91-180 days'          = 0
            '180+ days'            = 0
        }
        $credentialCounts = @{
            'Owned app with credentials'       = 0
            'Owned app without credentials'    = 0
            'Owned app with expired material'  = 0
            'Credential inventory unavailable' = 0
        }
        $thirdPartyList = [System.Collections.Generic.List[object]]::new()
        $inactiveList = [System.Collections.Generic.List[object]]::new()
        $staleList = [System.Collections.Generic.List[object]]::new()
        $expiredCredentialsList = [System.Collections.Generic.List[object]]::new()
        $ownedWithoutCredentialsList = [System.Collections.Generic.List[object]]::new()
        $reviewCandidates = [System.Collections.Generic.List[object]]::new()

        foreach ($app in $appData) {
            $source = if ($app.Source) { $app.Source } else { 'Unknown' }
            if (-not $sourceCounts.ContainsKey($source)) {
                $sourceCounts[$source] = 0
            }
            $sourceCounts[$source]++

            if ($source -eq 'First Party') {
                $firstPartyApps++
            } elseif ($source -eq 'Microsoft') {
                $microsoftApps++
            } elseif ($source -eq 'Third Party') {
                $thirdPartyApps++
                $thirdPartyList.Add($app)
            }

            if ($app.ServicePrincipalType -eq 'ManagedIdentity') {
                $managedIdentityApps++
            }

            $permissionType = if ($app.PermissionType) { $app.PermissionType } else { 'None' }
            if (-not $permissionCounts.ContainsKey($permissionType)) {
                $permissionCounts[$permissionType] = 0
            }
            $permissionCounts[$permissionType]++

            if ($permissionType -match 'Delegated') {
                $delegatedPermissionApps++
            }
            if ($permissionType -match 'Application') {
                $applicationPermissionApps++
            }
            if ($permissionType -eq 'None') {
                $noPermissionApps++
            }

            if ($source -eq 'First Party') {
                $appsWithCredentialInventory++
                if ($app.KeysCount -gt 0) {
                    $appsWithOwnedCredentials++
                    $credentialCounts['Owned app with credentials']++
                } else {
                    $appsWithoutOwnedCredentials++
                    $credentialCounts['Owned app without credentials']++
                    $ownedWithoutCredentialsList.Add($app)
                }
                if ($app.KeysExpired -in @('Yes', 'All Yes')) {
                    $appsWithExpiredOwnedCredentials++
                    $credentialCounts['Owned app with expired material']++
                    $expiredCredentialsList.Add($app)
                }
            } else {
                $appsWithoutCredentialInventory++
                $credentialCounts['Credential inventory unavailable']++
            }

            if ($null -eq $app.DaysSinceLastActivity) {
                $inactiveApps++
                $activityCounts['No activity observed']++
                $inactiveList.Add($app)
            } elseif ($app.DaysSinceLastActivity -le 30) {
                $recentApps++
                $activityCounts['0-30 days']++
            } elseif ($app.DaysSinceLastActivity -le 90) {
                $activityCounts['31-90 days']++
            } elseif ($app.DaysSinceLastActivity -le 180) {
                $staleApps++
                $activityCounts['91-180 days']++
                $staleList.Add($app)
            } else {
                $staleApps++
                $activityCounts['180+ days']++
                $staleList.Add($app)
            }

            $reviewFlags = [System.Collections.Generic.List[string]]::new()
            if ($source -eq 'Third Party') {
                $reviewFlags.Add('Third-party application')
            }
            if ($app.ServicePrincipalType -eq 'ManagedIdentity') {
                $reviewFlags.Add('Managed identity')
            }
            if ($permissionType -match 'Application') {
                $reviewFlags.Add('Application permissions')
            }
            if ($source -eq 'First Party' -and $app.KeysCount -eq 0) {
                $reviewFlags.Add('Owned app without credentials')
            }
            if ($source -eq 'First Party' -and $app.KeysExpired -in @('Yes', 'All Yes')) {
                $reviewFlags.Add('Expired credential material')
            }
            if ($null -eq $app.DaysSinceLastActivity) {
                $reviewFlags.Add('No activity observed')
            } elseif ($app.DaysSinceLastActivity -gt 180) {
                $reviewFlags.Add('Stale activity')
            }

            if ($reviewFlags.Count -gt 0) {
                $reviewFlagsText = $reviewFlags.ToArray() -join ', '
                $reviewCandidates.Add(($app | Select-Object -Property *, @{ Name = 'ReviewFlags'; Expression = { $reviewFlagsText } }))
            }
        }

        $overview = @(
            [PSCustomObject]@{
                TotalApps                       = $totalApps
                FirstPartyApps                  = $firstPartyApps
                MicrosoftApps                   = $microsoftApps
                ThirdPartyApps                  = $thirdPartyApps
                ManagedIdentityApps             = $managedIdentityApps
                DelegatedPermissionApps         = $delegatedPermissionApps
                ApplicationPermissionApps       = $applicationPermissionApps
                NoPermissionApps                = $noPermissionApps
                InactiveApps                    = $inactiveApps
                RecentApps                      = $recentApps
                StaleApps                       = $staleApps
                AppsWithCredentialInventory     = $appsWithCredentialInventory
                AppsWithoutCredentialInventory  = $appsWithoutCredentialInventory
                AppsWithOwnedCredentials        = $appsWithOwnedCredentials
                AppsWithoutOwnedCredentials     = $appsWithoutOwnedCredentials
                AppsWithExpiredOwnedCredentials = $appsWithExpiredOwnedCredentials
            }
        )

        $sourceDistribution = @(
            foreach ($key in $sourceCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $sourceCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $permissionDistribution = @(
            foreach ($key in $permissionCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $permissionCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $activityDistribution = @(
            foreach ($key in $activityCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $activityCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $credentialDistribution = @(
            foreach ($key in $credentialCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $credentialCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $topStaleApps = @($appData | Where-Object { $null -ne $_.DaysSinceLastActivity } | Sort-Object DaysSinceLastActivity -Descending | Select-Object -First 10)

        [PSCustomObject]@{
            Overview                = $overview
            SourceDistribution      = $sourceDistribution
            PermissionDistribution  = $permissionDistribution
            ActivityDistribution    = $activityDistribution
            CredentialDistribution  = $credentialDistribution
            TopStaleApps            = $topStaleApps
            ThirdPartyApps          = @($thirdPartyList)
            InactiveApps            = @($inactiveList)
            StaleApps               = @($staleList | Sort-Object DaysSinceLastActivity -Descending)
            ExpiredCredentials      = @($expiredCredentialsList)
            OwnedWithoutCredentials = @($ownedWithoutCredentialsList)
            ReviewCandidates        = @($reviewCandidates)
        }
    }
    Variables  = @{

    }
    Solution   = {
        $appSummary = $Script:Reporting['Apps']['Summary']
        $appData = @($Script:Reporting['Apps']['Data'])
        $appCount = $appData.Count

        if ($appData) {
            $appTableConditions = {
                New-HTMLTableCondition -Name 'Source' -Operator eq -Value 'First Party' -ComparisonType string -BackgroundColor LightGreen
                New-HTMLTableCondition -Name 'Source' -Operator eq -Value 'Microsoft' -ComparisonType string -BackgroundColor LightBlue
                New-HTMLTableCondition -Name 'Source' -Operator eq -Value 'Third Party' -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'Source', 'ApplicationName'
                New-HTMLTableCondition -Name 'ServicePrincipalType' -Operator eq -Value 'ManagedIdentity' -ComparisonType string -BackgroundColor LaserLemon -HighlightHeaders 'ServicePrincipalType', 'ApplicationName'
                New-HTMLTableCondition -Name 'PermissionType' -Operator eq -Value 'Application' -ComparisonType string -BackgroundColor LightSalmon -HighlightHeaders 'PermissionType'
                New-HTMLTableCondition -Name 'PermissionType' -Operator eq -Value 'Delegated & Application' -ComparisonType string -BackgroundColor Orange -HighlightHeaders 'PermissionType'
                New-HTMLTableCondition -Name 'PermissionType' -Operator eq -Value 'Delegated' -ComparisonType string -BackgroundColor LightSkyBlue -HighlightHeaders 'PermissionType'
                New-HTMLTableCondition -Name 'DaysSinceLastActivity' -Operator gt -Value 180 -ComparisonType number -BackgroundColor Salmon -HighlightHeaders 'DaysSinceLastActivity', 'MostRecentActivityDate', 'ActivityLevel'
                New-HTMLTableCondition -Name 'DaysSinceLastActivity' -Operator betweenInclusive -Value 91, 180 -ComparisonType number -BackgroundColor PeachOrange -HighlightHeaders 'DaysSinceLastActivity', 'MostRecentActivityDate'
                New-HTMLTableCondition -Name 'DaysSinceLastActivity' -Operator le -Value 30 -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'DaysSinceLastActivity', 'MostRecentActivityDate'
                New-HTMLTableCondition -Name 'KeysExpired' -Operator eq -Value 'Yes' -ComparisonType string -BackgroundColor OrangeRed -HighlightHeaders 'KeysExpired', 'DaysToExpireOldest', 'DaysToExpireNewest'
                New-HTMLTableCondition -Name 'KeysExpired' -Operator eq -Value 'All Yes' -ComparisonType string -BackgroundColor Red -HighlightHeaders 'KeysExpired', 'DaysToExpireOldest', 'DaysToExpireNewest'
                New-HTMLTableConditionGroup -Conditions {
                    New-HTMLTableCondition -Name 'Source' -Operator eq -Value 'First Party' -ComparisonType string
                    New-HTMLTableCondition -Name 'KeysCount' -Operator eq -Value 0 -ComparisonType number
                } -Logic AND -BackgroundColor Salmon -HighlightHeaders 'Source', 'KeysCount', 'KeysExpired'
                New-HTMLTableCondition -Name 'ActivityLevel' -Operator eq -Value 'Unknown' -ComparisonType string -BackgroundColor LightGray -HighlightHeaders 'ActivityLevel', 'DataQuality'
            }

            New-HTMLTabPanel {
                New-HTMLTab -Name "Overview ($appCount)" {
                    if ($appSummary -and $appSummary.Overview) {
                        $overview = $appSummary.Overview[0]
                        New-HTMLSection -HeaderText 'Application Inventory Overview' -Density Compact {
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Total Apps' -Number $overview.TotalApps -Subtitle 'Service principals in scope' -Icon '📱' -IconColor '#0078d4' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'First / Microsoft / Third Party' -Number "$($overview.FirstPartyApps) / $($overview.MicrosoftApps) / $($overview.ThirdPartyApps)" -Subtitle 'Source split' -Icon '🌐' -IconColor '#198754' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Managed Identities' -Number $overview.ManagedIdentityApps -Subtitle 'Workload identities in the app set' -Icon '🧩' -IconColor '#6f42c1' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Inactive / Stale' -Number "$($overview.InactiveApps) / $($overview.StaleApps)" -Subtitle 'No activity or 90+ day activity age' -Icon '⏱️' -IconColor '#dc3545' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Delegated Permissions' -Number $overview.DelegatedPermissionApps -Subtitle 'Apps with user-granted access' -Icon '👤' -IconColor '#20c997' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Application Permissions' -Number $overview.ApplicationPermissionApps -Subtitle 'Apps with app-only grants' -Icon '🔒' -IconColor '#fd7e14' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Owned Credentials' -Number "$($overview.AppsWithOwnedCredentials) / $($overview.AppsWithoutOwnedCredentials)" -Subtitle 'Owned apps with and without credentials' -Icon '🔑' -IconColor '#ffc107' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Inventory Gaps' -Number $overview.AppsWithoutCredentialInventory -Subtitle 'Apps where credential material is not queryable' -Icon '📭' -IconColor '#6c757d' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Applications by Source' {
                                        foreach ($item in $appSummary.SourceDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Applications by Permission Type' {
                                        foreach ($item in $appSummary.PermissionDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Activity Distribution' {
                                        foreach ($item in $appSummary.ActivityDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Credential Inventory Distribution' {
                                        foreach ($item in $appSummary.CredentialDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                            }
                            if (@($appSummary.TopStaleApps).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Most Stale Observed Apps' -Invisible {
                                    New-HTMLPanel {
                                        New-HTMLChart -Title 'Days Since Last Activity' {
                                            foreach ($item in $appSummary.TopStaleApps) {
                                                New-ChartBar -Name $item.ApplicationName -Value $item.DaysSinceLastActivity
                                            }
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -HeaderText 'Overview Summary Table' {
                                New-HTMLTable -DataTable $appSummary.Overview -Filtering -ScrollX
                            }
                        } -Wrap wrap
                    }
                }
                New-HTMLTab -Name "Applications ($appCount)" {
                    New-HTMLTabPanel {
                        New-HTMLTab -Name "All Apps ($appCount)" {
                            New-HTMLSection -HeaderText 'All Applications' {
                                New-HTMLTable -DataTable $appData -Filtering $appTableConditions -ScrollX
                            }
                        }
                        New-HTMLTab -Name "Third Party ($(@($appSummary.ThirdPartyApps).Count))" {
                            if (@($appSummary.ThirdPartyApps).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Third-Party Applications' {
                                    New-HTMLTable -DataTable $appSummary.ThirdPartyApps -Filtering $appTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Third-Party Applications' {
                                    New-HTMLText -Text 'No third-party applications were found in the current scope.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Inactive ($(@($appSummary.InactiveApps).Count))" {
                            if (@($appSummary.InactiveApps).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Applications With No Observed Activity' {
                                    New-HTMLTable -DataTable $appSummary.InactiveApps -Filtering $appTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Applications With No Observed Activity' {
                                    New-HTMLText -Text 'No applications without observed activity were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Expired Credentials ($(@($appSummary.ExpiredCredentials).Count))" {
                            if (@($appSummary.ExpiredCredentials).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Owned Applications With Expired Credentials' {
                                    New-HTMLTable -DataTable $appSummary.ExpiredCredentials -Filtering $appTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Owned Applications With Expired Credentials' {
                                    New-HTMLText -Text 'No owned applications with expired credentials were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Owned Without Credentials ($(@($appSummary.OwnedWithoutCredentials).Count))" {
                            if (@($appSummary.OwnedWithoutCredentials).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Owned Applications Without Credentials' {
                                    New-HTMLTable -DataTable $appSummary.OwnedWithoutCredentials -Filtering $appTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Owned Applications Without Credentials' {
                                    New-HTMLText -Text 'No owned applications without credentials were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Review Queue ($(@($appSummary.ReviewCandidates).Count))" {
                            if (@($appSummary.ReviewCandidates).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Applications Requiring Review' {
                                    New-HTMLTable -DataTable $appSummary.ReviewCandidates -Filtering $appTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Applications Requiring Review' {
                                    New-HTMLText -Text 'No applications matched the current review criteria.' -Color Orange
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
