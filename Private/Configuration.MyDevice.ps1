$Script:Devices = [ordered] @{
    Name       = 'Azure Active Directory Devices'
    Enabled    = $true
    Execute    = {
        Get-MyDevice
    }
    Processing = {

    }
    Summary    = {
        $deviceData = @($Script:Reporting['Devices']['Data'])
        $totalDevices = $deviceData.Count
        $enabledDevices = 0
        $disabledDevices = 0
        $managedDevices = 0
        $compliantDevices = 0
        $synchronizedDevices = 0
        $ownerlessDevices = 0
        $multiOwnerDevices = 0
        $staleDevices = 0
        $neverSeenDevices = 0

        foreach ($device in $deviceData) {
            if ($device.Enabled) {
                $enabledDevices++
            } else {
                $disabledDevices++
            }
            if ($device.IsManaged) {
                $managedDevices++
            }
            if ($device.IsCompliant) {
                $compliantDevices++
            }
            if ($device.IsSynchronized) {
                $synchronizedDevices++
            }
            if (-not $device.OwnerCount) {
                $ownerlessDevices++
            } elseif ($device.OwnerCount -gt 1) {
                $multiOwnerDevices++
            }
            if ($null -eq $device.LastSeenDays) {
                $neverSeenDevices++
            } elseif ($device.LastSeenDays -gt 90) {
                $staleDevices++
            }
        }

        $overview = @(
            [PSCustomObject]@{
                TotalDevices        = $totalDevices
                EnabledDevices      = $enabledDevices
                DisabledDevices     = $disabledDevices
                ManagedDevices      = $managedDevices
                CompliantDevices    = $compliantDevices
                SynchronizedDevices = $synchronizedDevices
                OwnerlessDevices    = $ownerlessDevices
                MultiOwnerDevices   = $multiOwnerDevices
                StaleDevices        = $staleDevices
                NeverSeenDevices    = $neverSeenDevices
            }
        )

        $trustTypes = @(
            $deviceData |
            Group-Object TrustType |
            Sort-Object Count -Descending |
            ForEach-Object {
                [PSCustomObject]@{
                    Name  = if ($_.Name) { $_.Name } else { 'Not available' }
                    Count = $_.Count
                }
            }
        )
        $operatingSystems = @(
            $deviceData |
            Group-Object OperatingSystem |
            Sort-Object Count -Descending |
            ForEach-Object {
                [PSCustomObject]@{
                    Name  = if ($_.Name) { $_.Name } else { 'Not available' }
                    Count = $_.Count
                }
            }
        )
        $staleBuckets = @(
            [PSCustomObject]@{ Name = '0-30 days'; Count = @($deviceData.Where({ $null -ne $_.LastSeenDays -and $_.LastSeenDays -le 30 })).Count }
            [PSCustomObject]@{ Name = '31-90 days'; Count = @($deviceData.Where({ $null -ne $_.LastSeenDays -and $_.LastSeenDays -gt 30 -and $_.LastSeenDays -le 90 })).Count }
            [PSCustomObject]@{ Name = '91-180 days'; Count = @($deviceData.Where({ $null -ne $_.LastSeenDays -and $_.LastSeenDays -gt 90 -and $_.LastSeenDays -le 180 })).Count }
            [PSCustomObject]@{ Name = '180+ days'; Count = @($deviceData.Where({ $null -ne $_.LastSeenDays -and $_.LastSeenDays -gt 180 })).Count }
            [PSCustomObject]@{ Name = 'Never seen'; Count = $neverSeenDevices }
        )

        [PSCustomObject]@{
            Overview         = $overview
            TrustTypes       = $trustTypes
            OperatingSystems = $operatingSystems
            StaleBuckets     = $staleBuckets
        }
    }
    Variables  = @{

    }
    Solution   = {
        if ($Script:Reporting['Devices']['Summary']) {
            $summary = $Script:Reporting['Devices']['Summary']
            if ($summary.Overview) {
                $overview = $summary.Overview[0]
                New-HTMLSection -HeaderText 'Device Overview' -Density Compact {
                    New-HTMLSection -Invisible {
                        New-HTMLInfoCard -Title 'Total Devices' -Number $overview.TotalDevices -Subtitle 'All Entra devices in scope' -Icon '💻' -IconColor '#0078d4' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                        New-HTMLInfoCard -Title 'Enabled / Disabled' -Number "$($overview.EnabledDevices) / $($overview.DisabledDevices)" -Subtitle 'Account state split' -Icon '✅' -IconColor '#198754' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                        New-HTMLInfoCard -Title 'Managed / Compliant' -Number "$($overview.ManagedDevices) / $($overview.CompliantDevices)" -Subtitle 'Management and compliance posture' -Icon '🛡️' -IconColor '#6f42c1' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                        New-HTMLInfoCard -Title 'Stale / Never Seen' -Number "$($overview.StaleDevices) / $($overview.NeverSeenDevices)" -Subtitle 'Devices needing review' -Icon '⏱️' -IconColor '#fd7e14' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                    }
                    New-HTMLSection -Invisible {
                        New-HTMLInfoCard -Title 'Synchronized' -Number $overview.SynchronizedDevices -Subtitle 'Hybrid or synced inventory' -Icon '🔄' -IconColor '#20c997' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                        New-HTMLInfoCard -Title 'Ownerless Devices' -Number $overview.OwnerlessDevices -Subtitle 'No registered owners returned' -Icon '👤' -IconColor '#dc3545' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                        New-HTMLInfoCard -Title 'Multi-owner Devices' -Number $overview.MultiOwnerDevices -Subtitle 'More than one registered owner' -Icon '👥' -IconColor '#ffc107' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                    }
                    New-HTMLSection -Invisible {
                        New-HTMLPanel {
                            New-HTMLChart -Title 'Devices by Trust Type' {
                                foreach ($item in $summary.TrustTypes) {
                                    New-ChartPie -Name $item.Name -Value $item.Count
                                }
                            }
                        }
                        New-HTMLPanel {
                            New-HTMLChart -Title 'Device Staleness' {
                                foreach ($item in $summary.StaleBuckets) {
                                    New-ChartPie -Name $item.Name -Value $item.Count
                                }
                            }
                        }
                    }
                    New-HTMLSection -HeaderText 'Operating System Distribution' -Invisible {
                        New-HTMLPanel {
                            New-HTMLChart -Title 'Devices by Operating System' {
                                foreach ($item in ($summary.OperatingSystems | Select-Object -First 10)) {
                                    New-ChartBar -Name $item.Name -Value $item.Count
                                }
                            }
                        }
                    }
                } -Wrap wrap
            }
        }
        if ($Script:Reporting['Devices']['Data']) {
            New-HTMLSection -HeaderText 'Device Details' {
            New-HTMLTable -DataTable $Script:Reporting['Devices']['Data'] -Filtering {
                New-HTMLTableCondition -Name 'Enabled' -Value $true -Operator eq -ComparisonType string -BackgroundColor MediumSpringGreen
                New-HTMLTableCondition -Name 'Enabled' -Value $false -Operator eq -ComparisonType string -BackgroundColor Cinnabar
                New-HTMLTableCondition -Name 'IsManaged' -Value $true -Operator eq -ComparisonType string -BackgroundColor MediumSpringGreen
                New-HTMLTableCondition -Name 'IsManaged' -Value $false -Operator eq -ComparisonType string -BackgroundColor Cinnabar
                New-HTMLTableCondition -Name 'IsCompliant' -Value $true -Operator eq -ComparisonType string -BackgroundColor MediumSpringGreen
                New-HTMLTableCondition -Name 'IsCompliant' -Value $false -Operator eq -ComparisonType string -BackgroundColor Cinnabar
                New-HTMLTableCondition -Name 'IsSynchronized' -Value $true -Operator eq -ComparisonType string -BackgroundColor MediumSpringGreen
                New-HTMLTableCondition -Name 'IsSynchronized' -Value $false -Operator eq -ComparisonType string -BackgroundColor Cinnabar
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastSeenDays', 'LastSeen'
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastSeenDays', 'LastSeen'
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastSeenDays', 'LastSeen'
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastSeenDays', 'LastSeen'
                New-HTMLTableCondition -Name 'OwnerCount' -Value 1 -Operator gt -ComparisonType number -BackgroundColor LightSkyBlue -HighlightHeaders 'OwnerCount', 'OwnerDisplayName', 'OwnerUserPrincipalName'
                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
                New-HTMLTableCondition -Name 'OwnerEnabled' -ComparisonType string -Operator eq -Value $true -BackgroundColor MediumSpringGreen
                New-HTMLTableCondition -Name 'OwnerEnabled' -ComparisonType string -Operator eq -Value $false -BackgroundColor Cinnabar
            } -ScrollX
            }
        }
    }
}
