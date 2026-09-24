BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsPagedInventory.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsObjectProperty.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Test-GraphEssentialsAutopilotSerialNumber.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsAutopilotLookup.ps1')

    function Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
        param([switch] $All, $Property, $ErrorAction)
    }
    function Invoke-MgGraphRequest { param($Method, $Uri, $OutputType, $ErrorAction) }
}

Describe 'Get-GraphEssentialsAutopilotLookup' {
    It 'loads association fields without an Autopilot selected-property query' {
        Mock Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
            param($Property)
            if ($Property) {
                throw 'Autopilot selected-property queries are unavailable'
            }
            [PSCustomObject] @{
                Id                           = 'autopilot-1'
                ManagedDeviceId              = 'managed-1'
                AzureActiveDirectoryDeviceId = 'device-1'
                SerialNumber                 = 'serial-1'
                GroupTag                     = 'pilot'
            }
        }

        $lookup = Get-GraphEssentialsAutopilotLookup

        $lookup.InventoryLoaded | Should -BeTrue
        $lookup.ByManagedDeviceId['managed-1'].Id | Should -Be 'autopilot-1'
        $lookup.ByAzureAdDeviceId['device-1'].Id | Should -Be 'autopilot-1'
        $lookup.BySerialNumber['serial-1'].GroupTag | Should -Be 'pilot'
        Should -Invoke Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -Times 1 -Exactly
    }

    It 'uses retrying pages without a selected-property query when progress is requested' {
        Mock Get-MgDeviceManagementWindowsAutopilotDeviceIdentity { throw 'SDK inventory should not run' }
        Mock Invoke-MgGraphRequest {
            [pscustomobject] @{ value = @([pscustomobject] @{
                id = 'autopilot-1'; managedDeviceId = 'managed-1'
                azureActiveDirectoryDeviceId = 'device-1'; serialNumber = 'serial-1'
            }) }
        }

        $records = @(Get-GraphEssentialsAutopilotLookup -ReportProgress 6>&1)
        $lookup = @($records | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })[0]
        $progress = @($records | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } | ForEach-Object { [string] $_.MessageData })

        $lookup.InventoryLoaded | Should -BeTrue
        $lookup.ByManagedDeviceId['managed-1'].Id | Should -Be 'autopilot-1'
        ($progress -join "`n") | Should -Match '1 records across 1 page'
        ($progress -join "`n") | Should -Match 'Graph inventory \(Windows Autopilot identities\)'
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq '/v1.0/deviceManagement/windowsAutopilotDeviceIdentities'
        }
        Should -Invoke Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -Times 0 -Exactly
    }

    It 'returns an unloaded lookup without partial associations after a later page fails' {
        Mock Invoke-MgGraphRequest {
            if ($Uri -like '*page2*') { throw 'Stream does not support reading' }
            [pscustomobject] @{
                value = @([pscustomobject] @{ id = 'autopilot-1'; managedDeviceId = 'managed-1' })
                '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities?page2'
            }
        }
        Mock Start-Sleep {}

        $warning = $null
        $lookup = Get-GraphEssentialsAutopilotLookup -ReportProgress -WarningAction SilentlyContinue -WarningVariable warning

        $lookup.InventoryLoaded | Should -BeFalse
        $lookup.ByManagedDeviceId.Count | Should -Be 0
        [string] $warning | Should -Match 'page 2 failed after 3 attempt'
        Should -Invoke Invoke-MgGraphRequest -Times 4 -Exactly
    }
}
