BeforeAll {
    . (Join-Path $PSScriptRoot '..\Public\Get-MyDeviceIntune.ps1')

    function Get-MgDeviceManagementManagedDevice {}
    function Get-MgDevice {}
}

Describe 'Get-MyDeviceIntune' {
    BeforeEach {
        $script:Devices = $null
        $script:DevicesDate = $null

        Mock Get-MgDeviceManagementManagedDevice {
            @(
                [PSCustomObject] @{
                    DeviceName       = 'iPhone-01'
                    Id               = 'managed-1'
                    AzureAdDeviceId  = 'device-1'
                    LastSyncDateTime = (Get-Date).AddDays(-10)
                    OperatingSystem  = 'iOS'
                    OSVersion        = '17.0'
                }
            )
        }

        Mock Get-MgDevice {
            @(
                [PSCustomObject] @{
                    DeviceId = 'device-1'
                    Id       = 'entra-1'
                }
            )
        }
    }

    It 'populates EntraDeviceObjectId on the default path' {
        $devices = @(Get-MyDeviceIntune -Force)

        $devices.Count | Should -Be 1
        $devices[0].ManagedDeviceId | Should -Be 'managed-1'
        $devices[0].EntraDeviceObjectId | Should -Be 'entra-1'
    }

    It 'continues Intune enumeration when the default Entra lookup fails' {
        Mock Get-MgDevice {
            throw 'Entra lookup failed'
        }

        $devices = @(Get-MyDeviceIntune -Force)

        $devices.Count | Should -Be 1
        $devices[0].ManagedDeviceId | Should -Be 'managed-1'
        $devices[0].EntraDeviceObjectId | Should -Be $null
    }
}
