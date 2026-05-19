BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsObjectProperty.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsAutopilotLookup.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Find-GraphEssentialsAutopilotDevice.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Get-MyDeviceIntune.ps1')

    function Get-MgDeviceManagementManagedDevice {}
    function Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {}
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

        Mock Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
            @()
        }
    }

    It 'populates EntraDeviceObjectId on the default path' {
        $devices = @(Get-MyDeviceIntune -Force)

        $devices.Count | Should -Be 1
        $devices[0].ManagedDeviceId | Should -Be 'managed-1'
        $devices[0].EntraDeviceObjectId | Should -Be 'entra-1'
    }

    It 'populates EntraDeviceObjectId on the filtered path' {
        Mock Get-MgDevice {
            @(
                [PSCustomObject] @{
                    DeviceId             = 'device-1'
                    Id                   = 'entra-1'
                    TrustType            = 'Workplace'
                    OnPremisesSyncEnabled = $false
                }
            )
        }

        $devices = @(Get-MyDeviceIntune -Type 'AzureAD registered' -Force)

        $devices.Count | Should -Be 1
        $devices[0].EntraDeviceObjectId | Should -Be 'entra-1'
        $devices[0].TrustType | Should -Be 'AzureAD registered'
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

    It 'falls back to registered Intune state when Entra trust metadata is unavailable' {
        Mock Get-MgDevice {
            @()
        }
        Mock Get-MgDeviceManagementManagedDevice {
            @(
                [PSCustomObject] @{
                    DeviceName              = 'Android-Orphan'
                    Id                      = 'managed-orphan'
                    AzureAdDeviceId         = 'device-orphan'
                    LastSyncDateTime        = (Get-Date).AddDays(-30)
                    OperatingSystem         = 'Android'
                    OSVersion               = '14'
                    DeviceRegistrationState = 'registered'
                    AzureAdRegistered       = $true
                }
            )
        }

        $devices = @(Get-MyDeviceIntune -Type 'AzureAD registered' -Force)

        $devices.Count | Should -Be 1
        $devices[0].TrustType | Should -Be 'AzureAD registered'
    }

    It 'enriches managed devices with Autopilot identity metadata' {
        Mock Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
            @(
                [PSCustomObject] @{
                    Id                           = 'autopilot-1'
                    ManagedDeviceId              = 'managed-1'
                    AzureActiveDirectoryDeviceId = 'device-1'
                    SerialNumber                 = 'serial-1'
                    GroupTag                     = 'pilot'
                    EnrollmentState              = 'enrolled'
                    LastContactedDateTime        = (Get-Date).AddDays(-5)
                    UserPrincipalName            = 'user.one@contoso.com'
                }
            )
        }

        $devices = @(Get-MyDeviceIntune -IncludeAutopilotInventory -Force)

        $devices.Count | Should -Be 1
        $devices[0].AutopilotInventoryLoaded | Should -BeTrue
        $devices[0].AutopilotOnboarded | Should -BeTrue
        $devices[0].AutopilotDeviceId | Should -Be 'autopilot-1'
        $devices[0].AutopilotGroupTag | Should -Be 'pilot'
        $devices[0].AutopilotEnrollmentState | Should -Be 'enrolled'
    }
}
