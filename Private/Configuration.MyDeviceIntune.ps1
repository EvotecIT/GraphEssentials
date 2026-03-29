$Script:DevicesIntune = [ordered] @{
    Name       = 'Azure Active Directory Devices Intune'
    Enabled    = $true
    Execute    = {
        Get-MyDeviceIntune
    }
    Processing = {

    }
    Summary    = {
        $deviceData = @($Script:Reporting['DevicesIntune']['Data'])
        $totalDevices = $deviceData.Count
        $compliantDevices = 0
        $encryptedDevices = 0
        $azureAdRegisteredDevices = 0
        $detailedInventoryLoaded = 0
        $staleDevices = 0
        $ownerTypeCounts = @{}
        $managementAgentCounts = @{}
        $complianceStateCounts = @{}
        $operatingSystemCounts = @{}

        foreach ($device in $deviceData) {
            if ($device.ComplianceState -eq 'compliant') {
                $compliantDevices++
            }
            if ($device.IsEncrypted) {
                $encryptedDevices++
            }
            if ($device.AzureAdRegistered) {
                $azureAdRegisteredDevices++
            }
            if ($device.DetailedInventoryLoaded) {
                $detailedInventoryLoaded++
            }
            if ($null -ne $device.LastSeenDays -and $device.LastSeenDays -gt 90) {
                $staleDevices++
            }

            $ownerType = if ($device.ManagedDeviceOwnerType) { $device.ManagedDeviceOwnerType } else { 'Not available' }
            $managementAgent = if ($device.ManagementAgent) { $device.ManagementAgent } else { 'Not available' }
            $complianceState = if ($device.ComplianceState) { $device.ComplianceState } else { 'Not available' }
            $operatingSystem = if ($device.OperatingSystem) { $device.OperatingSystem } else { 'Not available' }

            if (-not $ownerTypeCounts.ContainsKey($ownerType)) { $ownerTypeCounts[$ownerType] = 0 }
            if (-not $managementAgentCounts.ContainsKey($managementAgent)) { $managementAgentCounts[$managementAgent] = 0 }
            if (-not $complianceStateCounts.ContainsKey($complianceState)) { $complianceStateCounts[$complianceState] = 0 }
            if (-not $operatingSystemCounts.ContainsKey($operatingSystem)) { $operatingSystemCounts[$operatingSystem] = 0 }

            $ownerTypeCounts[$ownerType]++
            $managementAgentCounts[$managementAgent]++
            $complianceStateCounts[$complianceState]++
            $operatingSystemCounts[$operatingSystem]++
        }

        $overview = @(
            [PSCustomObject]@{
                TotalDevices            = $totalDevices
                CompliantDevices        = $compliantDevices
                NonCompliantDevices     = $totalDevices - $compliantDevices
                EncryptedDevices        = $encryptedDevices
                AzureAdRegistered       = $azureAdRegisteredDevices
                DetailedInventoryLoaded = $detailedInventoryLoaded
                StaleDevices            = $staleDevices
            }
        )

        $ownerTypes = @(
            foreach ($key in $ownerTypeCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $ownerTypeCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $managementAgents = @(
            foreach ($key in $managementAgentCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $managementAgentCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $complianceStates = @(
            foreach ($key in $complianceStateCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $complianceStateCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $operatingSystems = @(
            foreach ($key in $operatingSystemCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $operatingSystemCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        [PSCustomObject]@{
            Overview         = $overview
            OwnerTypes       = $ownerTypes
            ManagementAgents = $managementAgents
            ComplianceStates = $complianceStates
            OperatingSystems = $operatingSystems
        }
    }
    Variables  = @{

    }
    Solution   = {
        if ($Script:Reporting['DevicesIntune']['Summary']) {
            $summary = $Script:Reporting['DevicesIntune']['Summary']
            if ($summary.Overview) {
                $overview = $summary.Overview[0]
                New-HTMLSection -HeaderText 'Intune Device Overview' -Density Compact {
                    New-HTMLSection -Invisible {
                        New-HTMLInfoCard -Title 'Total Devices' -Number $overview.TotalDevices -Subtitle 'All Intune managed devices in scope' -Icon '📱' -IconColor '#0078d4' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                        New-HTMLInfoCard -Title 'Compliant / Noncompliant' -Number "$($overview.CompliantDevices) / $($overview.NonCompliantDevices)" -Subtitle 'Compliance state split' -Icon '🛡️' -IconColor '#198754' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                        New-HTMLInfoCard -Title 'Encrypted' -Number $overview.EncryptedDevices -Subtitle 'Devices reporting encryption' -Icon '🔒' -IconColor '#6f42c1' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                        New-HTMLInfoCard -Title 'Detailed Inventory' -Number $overview.DetailedInventoryLoaded -Subtitle 'Per-device detailed lookups loaded' -Icon '📦' -IconColor '#fd7e14' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                    }
                    New-HTMLSection -Invisible {
                        New-HTMLInfoCard -Title 'Azure AD Registered' -Number $overview.AzureAdRegistered -Subtitle 'Managed devices linked to Entra' -Icon '☁️' -IconColor '#20c997' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                        New-HTMLInfoCard -Title 'Stale Devices' -Number $overview.StaleDevices -Subtitle 'No sync in more than 90 days' -Icon '⏱️' -IconColor '#dc3545' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                    }
                    New-HTMLSection -Invisible {
                        New-HTMLPanel {
                            New-HTMLChart -Title 'Compliance State Distribution' {
                                foreach ($item in $summary.ComplianceStates) {
                                    New-ChartPie -Name $item.Name -Value $item.Count
                                }
                            }
                        }
                        New-HTMLPanel {
                            New-HTMLChart -Title 'Management Agent Distribution' {
                                foreach ($item in $summary.ManagementAgents) {
                                    New-ChartPie -Name $item.Name -Value $item.Count
                                }
                            }
                        }
                    }
                    New-HTMLSection -HeaderText 'Ownership and Platform Distribution' -Invisible {
                        New-HTMLPanel {
                            New-HTMLChart -Title 'Managed Device Owner Types' {
                                foreach ($item in $summary.OwnerTypes) {
                                    New-ChartPie -Name $item.Name -Value $item.Count
                                }
                            }
                        }
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
        if ($Script:Reporting['DevicesIntune']['Data']) {
            New-HTMLSection -HeaderText 'Intune Device Details' {
            New-HTMLTable -DataTable $Script:Reporting['DevicesIntune']['Data'] -Filtering {
                New-HTMLTableCondition -Name 'ComplianceState' -Operator eq -Value 'compliant' -ComparisonType string -BackgroundColor MediumSpringGreen -FailBackgroundColor Cinnabar
                New-HTMLTableCondition -Name 'DetailedInventoryLoaded' -Operator eq -Value $true -ComparisonType string -BackgroundColor LightSkyBlue
                New-HTMLTableCondition -Name 'DetailedInventoryLoaded' -Operator eq -Value $false -ComparisonType string -BackgroundColor OldGold -HighlightHeaders 'DetailedInventoryLoaded', 'ActivationLockBypassCode', 'EthernetMacAddress', 'Iccid', 'Notes', 'PhysicalMemoryInBytes', 'Udid'
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastSeenDays', 'LastSeen'
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastSeenDays', 'LastSeen'
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastSeenDays', 'LastSeen'
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastSeenDays', 'LastSeen'
            } -ScrollX
            }
        }
    }
}
