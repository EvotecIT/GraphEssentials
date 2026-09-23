BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsObjectProperty.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Test-GraphEssentialsAutopilotSerialNumber.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsAutopilotLookup.ps1')

    function Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
        param([switch] $All, $Property, $ErrorAction)
    }
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
}
