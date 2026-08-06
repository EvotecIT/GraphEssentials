BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsObjectProperty.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Test-GraphEssentialsAutopilotSerialNumber.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsAutopilotLookup.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Find-GraphEssentialsAutopilotDevice.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Get-MyDeviceIntune.ps1')

    function Get-MgDeviceManagementManagedDevice { param([switch] $All, $Property, $ManagedDeviceId, $ErrorAction) }
    function Get-MgDeviceManagementWindowsAutopilotDeviceIdentity { param([switch] $All, $Property, $ErrorAction) }
    function Get-MgDevice { param([switch] $All, $Property, $ErrorAction) }
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

    It 'continues type-filtered enumeration after a rejected managed device' {
        Mock Get-MgDevice {
            @(
                [PSCustomObject] @{
                    DeviceId              = 'device-rejected'
                    Id                    = 'entra-rejected'
                    TrustType             = 'AzureAD'
                    OnPremisesSyncEnabled = $false
                }
                [PSCustomObject] @{
                    DeviceId              = 'device-matching'
                    Id                    = 'entra-matching'
                    TrustType             = 'Workplace'
                    OnPremisesSyncEnabled = $false
                }
            )
        }
        Mock Get-MgDeviceManagementManagedDevice {
            @(
                [PSCustomObject] @{
                    DeviceName       = 'Rejected'
                    Id               = 'managed-rejected'
                    AzureAdDeviceId  = 'device-rejected'
                    LastSyncDateTime = (Get-Date).AddDays(-20)
                }
                [PSCustomObject] @{
                    DeviceName       = 'Matching'
                    Id               = 'managed-matching'
                    AzureAdDeviceId  = 'device-matching'
                    LastSyncDateTime = (Get-Date).AddDays(-10)
                }
            )
        }

        $devices = @(Get-MyDeviceIntune -Type 'AzureAD registered' -Force)

        $devices | Should -HaveCount 1
        $devices[0].ManagedDeviceId | Should -Be 'managed-matching'
    }

    It 'continues synchronized filtering after an unsynchronized managed device' {
        Mock Get-MgDevice {
            @(
                [PSCustomObject] @{
                    DeviceId              = 'device-unsynchronized'
                    Id                    = 'entra-unsynchronized'
                    TrustType             = 'AzureAD'
                    OnPremisesSyncEnabled = $false
                }
                [PSCustomObject] @{
                    DeviceId              = 'device-synchronized'
                    Id                    = 'entra-synchronized'
                    TrustType             = 'ServerAD'
                    OnPremisesSyncEnabled = $true
                }
            )
        }
        Mock Get-MgDeviceManagementManagedDevice {
            @(
                [PSCustomObject] @{
                    DeviceName       = 'Unsynchronized'
                    Id               = 'managed-unsynchronized'
                    AzureAdDeviceId  = 'device-unsynchronized'
                    LastSyncDateTime = (Get-Date).AddDays(-20)
                }
                [PSCustomObject] @{
                    DeviceName       = 'Synchronized'
                    Id               = 'managed-synchronized'
                    AzureAdDeviceId  = 'device-synchronized'
                    LastSyncDateTime = (Get-Date).AddDays(-10)
                }
            )
        }

        $devices = @(Get-MyDeviceIntune -Synchronized -Force)

        $devices | Should -HaveCount 1
        $devices[0].ManagedDeviceId | Should -Be 'managed-synchronized'
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

    It 'does not infer Entra trust from Intune registration state' {
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

        $devices.Count | Should -Be 0
    }

    It 'enriches managed devices with Autopilot identity metadata' {
        Mock Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
            @(
                [PSCustomObject] @{
                    Id                           = 'autopilot-1'
                    ManagedDeviceId              = 'managed-1'
                    AzureActiveDirectoryDeviceId = 'device-1'
                    SerialNumber                 = 'serial-1'
                    ResourceName                 = 'serial-1'
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
        $devices[0].AutopilotManagedDeviceId | Should -Be 'managed-1'
        $devices[0].AutopilotAzureAdDeviceId | Should -Be 'device-1'
        $devices[0].AutopilotResourceName | Should -Be 'serial-1'
        $devices[0].AutopilotGroupTag | Should -Be 'pilot'
        $devices[0].AutopilotSerialNumber | Should -Be 'serial-1'
        $devices[0].AutopilotEnrollmentState | Should -Be 'enrolled'
        $devices[0].AutopilotLastContactedDays | Should -BeGreaterOrEqual 4
    }

    It 'does not match Autopilot devices by duplicate serial number alone' {
        Mock Get-MgDevice {
            @()
        }
        Mock Get-MgDeviceManagementManagedDevice {
            @(
                [PSCustomObject] @{
                    DeviceName       = 'Windows-DuplicateSerial'
                    Id               = 'managed-missing'
                    AzureAdDeviceId  = 'device-missing'
                    LastSyncDateTime = (Get-Date).AddDays(-10)
                    OperatingSystem  = 'Windows'
                    OSVersion        = '10.0.22631.5624'
                    SerialNumber     = 'duplicate-serial'
                }
            )
        }
        Mock Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
            @(
                [PSCustomObject] @{
                    Id             = 'autopilot-1'
                    SerialNumber   = 'duplicate-serial'
                    ManagedDeviceId = 'managed-other-1'
                }
                [PSCustomObject] @{
                    Id             = 'autopilot-2'
                    SerialNumber   = 'duplicate-serial'
                    ManagedDeviceId = 'managed-other-2'
                }
            )
        }

        $devices = @(Get-MyDeviceIntune -IncludeAutopilotInventory -Force)

        $devices.Count | Should -Be 1
        $devices[0].AutopilotInventoryLoaded | Should -BeTrue
        $devices[0].AutopilotOnboarded | Should -BeFalse
        $devices[0].AutopilotDeviceId | Should -Be $null
    }

    It 'uses the compact lifecycle projection when explicitly requested' {
        $script:CapturedManagedDeviceProperties = $null
        Mock Get-MgDeviceManagementManagedDevice {
            param($Property)
            $script:CapturedManagedDeviceProperties = @($Property)
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

        $devices = @(Get-MyDeviceIntune -PropertySet Lifecycle -Force)

        $devices | Should -HaveCount 1
        $script:CapturedManagedDeviceProperties | Should -Contain 'azureADDeviceId'
        $script:CapturedManagedDeviceProperties | Should -Contain 'deviceRegistrationState'
        $script:CapturedManagedDeviceProperties | Should -Contain 'serialNumber'
        $script:CapturedManagedDeviceProperties | Should -Not -Contain 'deviceActionResults'
        $script:CapturedManagedDeviceProperties | Should -Not -Contain 'remoteAssistanceSessionUrl'
    }

    It 'preserves the existing unprojected managed-device query by default' {
        $script:CapturedManagedDeviceProperties = $null
        $script:ManagedDevicePropertyWasBound = $null
        Mock Get-MgDeviceManagementManagedDevice {
            param($Property)
            $script:CapturedManagedDeviceProperties = @($Property)
            $script:ManagedDevicePropertyWasBound = $PSBoundParameters.ContainsKey('Property')
            @()
        }

        Get-MyDeviceIntune -Force | Out-Null

        $script:ManagedDevicePropertyWasBound | Should -BeFalse
    }

    It 'does not emit partial managed-device output when Graph enumeration fails' {
        Mock Get-MgDeviceManagementManagedDevice {
            [PSCustomObject] @{
                DeviceName       = 'Partial-Device'
                Id               = 'managed-partial'
                AzureAdDeviceId  = 'device-partial'
                LastSyncDateTime = (Get-Date).AddDays(-10)
            }
            throw 'managed-device page two failed'
        }

        $warning = $null
        $devices = @(Get-MyDeviceIntune -Force -WarningAction SilentlyContinue -WarningVariable warning)

        $devices | Should -HaveCount 0
        [string] $warning | Should -Match 'managed-device page two failed'
    }

    It 'requests only Autopilot properties used by device inventory output' {
        $script:CapturedAutopilotProperties = $null
        Mock Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
            param($Property)
            $script:CapturedAutopilotProperties = @($Property)
            @()
        }

        Get-MyDeviceIntune -IncludeAutopilotInventory -Force | Out-Null

        $script:CapturedAutopilotProperties | Should -Contain 'managedDeviceId'
        $script:CapturedAutopilotProperties | Should -Contain 'lastContactedDateTime'
        $script:CapturedAutopilotProperties | Should -Not -Contain 'manufacturer'
        $script:CapturedAutopilotProperties | Should -Not -Contain 'purchaseOrderIdentifier'
        $script:CapturedAutopilotProperties | Should -Not -Contain 'displayName'
    }
}
