$Script:Licenses = [ordered] @{
    Name       = 'Azure Licenses'
    Enabled    = $true
    Execute    = {
        Get-MyLicense
    }
    Processing = {

    }
    Summary    = {
        $licenseData = @($Script:Reporting['Licenses']['Data'])
        $totalLicenses = $licenseData.Count
        $enabledLicenses = 0
        $warningLicenses = 0
        $oversubscribedLicenses = 0
        $atCapacityLicenses = 0
        $highUsageLicenses = 0
        $unusedLicenses = 0
        $totalConsumed = 0
        $totalEnabledCapacity = 0
        $capabilityCounts = @{}
        $utilizationCounts = @{}
        $oversubscribedList = [System.Collections.Generic.List[object]]::new()
        $highUsageList = [System.Collections.Generic.List[object]]::new()
        $unusedList = [System.Collections.Generic.List[object]]::new()

        foreach ($license in $licenseData) {
            if ($license.CapabilityStatus -eq 'Enabled') {
                $enabledLicenses++
            } else {
                $warningLicenses++
            }

            if (-not $capabilityCounts.ContainsKey($license.CapabilityStatus)) {
                $capabilityCounts[$license.CapabilityStatus] = 0
            }
            $capabilityCounts[$license.CapabilityStatus]++

            if (-not $utilizationCounts.ContainsKey($license.UtilizationBand)) {
                $utilizationCounts[$license.UtilizationBand] = 0
            }
            $utilizationCounts[$license.UtilizationBand]++

            $totalConsumed += $license.LicensesUsedCount
            $totalEnabledCapacity += $license.LicenseCountEnabled

            if ($license.IsOversubscribed) {
                $oversubscribedLicenses++
                $oversubscribedList.Add($license)
            } elseif ($license.IsAtCapacity) {
                $atCapacityLicenses++
                $highUsageLicenses++
                $highUsageList.Add($license)
            } elseif ($license.LicensesUsedPercent -ge 70) {
                $highUsageLicenses++
                $highUsageList.Add($license)
            }

            if ($license.LicensesUsedPercent -eq 0) {
                $unusedLicenses++
                $unusedList.Add($license)
            }
        }

        if ($totalEnabledCapacity -gt 0) {
            $overallUsagePercent = [math]::Round(($totalConsumed / $totalEnabledCapacity) * 100, 0)
        } else {
            $overallUsagePercent = 0
        }

        $overview = @(
            [PSCustomObject]@{
                TotalLicenses        = $totalLicenses
                EnabledSkus          = $enabledLicenses
                NonEnabledSkus       = $warningLicenses
                OversubscribedSkus   = $oversubscribedLicenses
                HighUsageSkus        = $highUsageLicenses
                UnusedSkus           = $unusedLicenses
                TotalConsumedUnits   = $totalConsumed
                TotalEnabledCapacity = $totalEnabledCapacity
                OverallUsagePercent  = $overallUsagePercent
            }
        )

        $capabilityDistribution = @(
            foreach ($key in $capabilityCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $capabilityCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $utilizationDistribution = @(
            foreach ($key in $utilizationCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $utilizationCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $topByConsumption = @($licenseData | Sort-Object LicensesUsedCount -Descending | Select-Object -First 10)
        $topByUtilization = @($licenseData | Sort-Object LicensesUsedPercent -Descending | Select-Object -First 10)

        [PSCustomObject]@{
            Overview                = $overview
            CapabilityDistribution  = $capabilityDistribution
            UtilizationDistribution = $utilizationDistribution
            TopByConsumption        = $topByConsumption
            TopByUtilization        = $topByUtilization
            Oversubscribed          = @($oversubscribedList)
            HighUsage               = @($highUsageList)
            Unused                  = @($unusedList)
        }
    }
    Variables  = @{

    }
    Solution   = {
        $licenseSummary = $Script:Reporting['Licenses']['Summary']
        $licenseData = @($Script:Reporting['Licenses']['Data'])
        $licenseCount = $licenseData.Count

        if ($licenseData) {
            $licenseTableConditions = {
                New-HTMLTableCondition -Name 'CapabilityStatus' -Operator eq -Value 'Enabled' -ComparisonType string -BackgroundColor LightGreen -FailBackgroundColor Orange
                New-HTMLTableCondition -Name 'IsOversubscribed' -Operator eq -Value $true -ComparisonType string -BackgroundColor Alizarin -HighlightHeaders 'LicensesUsedCount', 'LicensesUsedPercent', 'LicensesAvailableCount'
                New-HTMLTableCondition -Name 'IsAtCapacity' -Operator eq -Value $true -ComparisonType string -BackgroundColor Salmon -HighlightHeaders 'LicensesUsedCount', 'LicensesUsedPercent', 'LicensesAvailableCount'
                New-HTMLTableCondition -Name 'LicensesUsedPercent' -Operator betweenInclusive -Value 70, 99 -ComparisonType number -BackgroundColor Orange -HighlightHeaders 'LicensesUsedCount', 'LicensesUsedPercent'
                New-HTMLTableCondition -Name 'LicensesUsedPercent' -Operator betweenInclusive -Value 40, 69 -ComparisonType number -BackgroundColor LightSkyBlue -HighlightHeaders 'LicensesUsedCount', 'LicensesUsedPercent'
                New-HTMLTableCondition -Name 'LicensesUsedPercent' -Operator betweenInclusive -Value 1, 39 -ComparisonType number -BackgroundColor Almond -HighlightHeaders 'LicensesUsedCount', 'LicensesUsedPercent'
                New-HTMLTableCondition -Name 'LicensesUsedPercent' -Operator eq -Value 0 -ComparisonType number -BackgroundColor LightGreen -HighlightHeaders 'LicensesUsedCount', 'LicensesUsedPercent'
                New-HTMLTableCondition -Name 'LicenseCountSuspended' -Operator gt -Value 0 -ComparisonType number -BackgroundColor PeachOrange -HighlightHeaders 'LicenseCountSuspended'
                New-HTMLTableCondition -Name 'LicenseCountWarning' -Operator gt -Value 0 -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LicenseCountWarning'
            }

            New-HTMLTabPanel {
                New-HTMLTab -Name "Overview ($licenseCount)" {
                    if ($licenseSummary -and $licenseSummary.Overview) {
                        $overview = $licenseSummary.Overview[0]
                        New-HTMLSection -HeaderText 'License Capacity Overview' -Density Compact {
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Total SKUs' -Number $overview.TotalLicenses -Subtitle 'Subscribed license products' -Icon '🎫' -IconColor '#0078d4' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Enabled / Other' -Number "$($overview.EnabledSkus) / $($overview.NonEnabledSkus)" -Subtitle 'Capability status split' -Icon '✅' -IconColor '#198754' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Oversubscribed' -Number $overview.OversubscribedSkus -Subtitle 'SKUs above provisioned capacity' -Icon '🚨' -IconColor '#dc3545' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'High Usage' -Number $overview.HighUsageSkus -Subtitle '70%+ used or fully allocated' -Icon '📈' -IconColor '#fd7e14' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Unused SKUs' -Number $overview.UnusedSkus -Subtitle 'No consumed units' -Icon '📦' -IconColor '#20c997' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Consumed Units' -Number $overview.TotalConsumedUnits -Subtitle 'Total assigned units across SKUs' -Icon '👥' -IconColor '#6f42c1' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Enabled Capacity' -Number $overview.TotalEnabledCapacity -Subtitle 'Provisioned enabled units' -Icon '🧮' -IconColor '#ffc107' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Overall Usage %' -Number $overview.OverallUsagePercent -Subtitle 'Consumed vs enabled capacity' -Icon '📊' -IconColor '#6c757d' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Capability Status Distribution' {
                                        foreach ($item in $licenseSummary.CapabilityDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'License Utilization Bands' {
                                        foreach ($item in $licenseSummary.UtilizationDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                            }
                            if (@($licenseSummary.TopByConsumption).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Top License Products' -Invisible {
                                    New-HTMLPanel {
                                        New-HTMLChart -Title 'Top By Consumed Units' {
                                            foreach ($item in $licenseSummary.TopByConsumption) {
                                                New-ChartBar -Name $item.Name -Value $item.LicensesUsedCount
                                            }
                                        }
                                    }
                                    New-HTMLPanel {
                                        New-HTMLChart -Title 'Top By Utilization %' {
                                            foreach ($item in $licenseSummary.TopByUtilization) {
                                                New-ChartBar -Name $item.Name -Value $item.LicensesUsedPercent
                                            }
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -HeaderText 'Overview Summary Table' {
                                New-HTMLTable -DataTable $licenseSummary.Overview -Filtering -ScrollX
                            }
                        } -Wrap wrap
                    }
                }

                New-HTMLTab -Name "Licenses ($licenseCount)" {
                    New-HTMLTabPanel {
                        New-HTMLTab -Name "All SKUs ($licenseCount)" {
                            New-HTMLSection -HeaderText 'All License SKUs' {
                                New-HTMLTable -DataTable $licenseData -Filtering $licenseTableConditions -ScrollX
                            }
                        }
                        New-HTMLTab -Name "Oversubscribed ($(@($licenseSummary.Oversubscribed).Count))" {
                            if (@($licenseSummary.Oversubscribed).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Oversubscribed License SKUs' {
                                    New-HTMLTable -DataTable $licenseSummary.Oversubscribed -Filtering $licenseTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Oversubscribed License SKUs' {
                                    New-HTMLText -Text 'No oversubscribed license SKUs were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "High Usage ($(@($licenseSummary.HighUsage).Count))" {
                            if (@($licenseSummary.HighUsage).Count -gt 0) {
                                New-HTMLSection -HeaderText 'High Usage License SKUs' {
                                    New-HTMLTable -DataTable $licenseSummary.HighUsage -Filtering $licenseTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'High Usage License SKUs' {
                                    New-HTMLText -Text 'No high usage license SKUs were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Unused ($(@($licenseSummary.Unused).Count))" {
                            if (@($licenseSummary.Unused).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Unused License SKUs' {
                                    New-HTMLTable -DataTable $licenseSummary.Unused -Filtering $licenseTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Unused License SKUs' {
                                    New-HTMLText -Text 'No unused license SKUs were found.' -Color Orange
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
