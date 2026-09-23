BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsPagedInventory.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsObjectProperty.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Test-GraphEssentialsAutopilotSerialNumber.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsAutopilotLookup.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Find-GraphEssentialsAutopilotDevice.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Get-MyDeviceIntune.ps1')

    function Get-MgDeviceManagementManagedDevice { param([switch] $All, $Property, $ManagedDeviceId, $ErrorAction) }
    function Get-MgDeviceManagementWindowsAutopilotDeviceIdentity { param([switch] $All, $Property, $ErrorAction) }
    function Get-MgDevice { param([switch] $All, $Property, $ErrorAction) }
    function Invoke-MgGraphRequest { param($Method, $Uri, $OutputType, $ErrorAction) }
}

Describe 'Get-MyDeviceIntune' {
    BeforeEach {
        $script:Devices = $null
        $script:DevicesDate = $null
        $script:DevicesScope = $null

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

        Mock Invoke-MgGraphRequest {
            if ($Uri -like '*/managedDevices*') {
                return [PSCustomObject] @{ value = @(
                    [PSCustomObject] @{ deviceName = 'Unsynchronized'; id = 'managed-unsynchronized'; azureADDeviceId = 'device-unsynchronized'; lastSyncDateTime = (Get-Date).AddDays(-20) }
                    [PSCustomObject] @{ deviceName = 'Synchronized'; id = 'managed-synchronized'; azureADDeviceId = 'device-synchronized'; lastSyncDateTime = (Get-Date).AddDays(-10) }
                ) }
            }
            [PSCustomObject] @{ value = @([PSCustomObject] @{
                deviceId = 'device-synchronized'; id = 'entra-synchronized'
                trustType = 'ServerAD'; onPremisesSyncEnabled = $true
            }) }
        }

        $devices = @(Get-MyDeviceIntune -Synchronized -PropertySet Computer -Force)

        $devices | Should -HaveCount 1
        $devices[0].ManagedDeviceId | Should -Be 'managed-synchronized'
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*onPremisesSyncEnabled%20eq%20true*'
        }
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

    It 'rejects computer inventory when an unfiltered Entra lookup fails' {
        Mock Invoke-MgGraphRequest {
            if ($Uri -like '*/devices?*') {
                throw 'Entra page two failed'
            }
            throw 'Managed inventory should not run'
        }

        $warning = $null
        $devices = @(Get-MyDeviceIntune -PropertySet Computer -Force -WarningAction SilentlyContinue -WarningVariable warning)

        $devices | Should -HaveCount 0
        [string] $warning | Should -Match 'Computer inventory is incomplete'
        Should -Invoke Invoke-MgGraphRequest -Times 0 -Exactly -ParameterFilter { $Uri -like '*/managedDevices*' }
    }

    It 'does not reuse a synchronized-only Entra cache for an unfiltered Intune inventory' {
        $script:Devices = @([PSCustomObject] @{
            DeviceId = 'synced-only'; Id = 'entra-synced'
            OnPremisesSyncEnabled = $true; TrustType = 'ServerAD'
        })
        $script:DevicesDate = Get-Date
        $script:DevicesScope = 'Synchronized'
        Mock Get-MgDevice {
            @([PSCustomObject] @{ DeviceId = 'device-1'; Id = 'entra-1' })
        }

        $devices = @(Get-MyDeviceIntune)

        $devices | Should -HaveCount 1
        $devices[0].EntraDeviceObjectId | Should -Be 'entra-1'
        Should -Invoke Get-MgDevice -Times 1 -Exactly
    }

    It 'reuses the synchronized Entra cache during the computer cleanup Intune read' {
        $script:Devices = @([PSCustomObject] @{
            DeviceId = 'device-1'; Id = 'entra-1'
            OnPremisesSyncEnabled = $true; TrustType = 'ServerAD'
        })
        $script:DevicesDate = Get-Date
        $script:DevicesScope = 'Synchronized'
        Mock Invoke-MgGraphRequest {
            if ($Uri -like '*/devices?*') { throw 'Entra inventory should be reused' }
            [PSCustomObject] @{ value = @([PSCustomObject] @{
                azureADDeviceId = 'device-1'; deviceName = 'DEVICE-01'
                id = 'managed-1'; lastSyncDateTime = '2026-09-01T10:00:00Z'
            }) }
        }

        $devices = @(Get-MyDeviceIntune -Synchronized -PropertySet Computer)

        $devices | Should -HaveCount 1
        $devices[0].EntraDeviceObjectId | Should -Be 'entra-1'
        Should -Invoke Invoke-MgGraphRequest -Times 0 -Exactly -ParameterFilter { $Uri -like '*/devices?*' }
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
        $devices[0].AutopilotOnboarded | Should -BeTrue
        $devices[0].AutopilotMatchAmbiguous | Should -BeTrue
        $devices[0].AutopilotDeviceId | Should -Be $null
    }

    It 'marks duplicate managed-device associations as ambiguous' {
        Mock Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
            @(
                [PSCustomObject] @{ Id = 'autopilot-1'; ManagedDeviceId = 'managed-1'; AzureActiveDirectoryDeviceId = 'device-1' }
                [PSCustomObject] @{ Id = 'autopilot-2'; ManagedDeviceId = 'managed-1'; AzureActiveDirectoryDeviceId = 'device-2' }
            )
        }

        $devices = @(Get-MyDeviceIntune -IncludeAutopilotInventory -Force)

        $devices | Should -HaveCount 1
        $devices[0].AutopilotMatchAmbiguous | Should -BeTrue
        $devices[0].AutopilotDeviceId | Should -Be $null
    }

    It 'marks duplicate Entra-device associations as ambiguous' {
        Mock Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
            @(
                [PSCustomObject] @{ Id = 'autopilot-1'; ManagedDeviceId = 'managed-other-1'; AzureActiveDirectoryDeviceId = 'device-1' }
                [PSCustomObject] @{ Id = 'autopilot-2'; ManagedDeviceId = 'managed-other-2'; AzureActiveDirectoryDeviceId = 'device-1' }
            )
        }

        $devices = @(Get-MyDeviceIntune -IncludeAutopilotInventory -Force)

        $devices | Should -HaveCount 1
        $devices[0].AutopilotMatchAmbiguous | Should -BeTrue
        $devices[0].AutopilotDeviceId | Should -Be $null
    }

    It 'marks conflicting unique association keys as ambiguous' {
        Mock Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
            @(
                [PSCustomObject] @{ Id = 'autopilot-1'; ManagedDeviceId = 'managed-1'; AzureActiveDirectoryDeviceId = 'device-other' }
                [PSCustomObject] @{ Id = 'autopilot-2'; ManagedDeviceId = 'managed-other'; AzureActiveDirectoryDeviceId = 'device-1' }
            )
        }

        $devices = @(Get-MyDeviceIntune -IncludeAutopilotInventory -Force)

        $devices | Should -HaveCount 1
        $devices[0].AutopilotMatchAmbiguous | Should -BeTrue
        $devices[0].AutopilotDeviceId | Should -Be $null
    }

    It 'marks a serial-only match with contradictory device IDs as ambiguous' {
        Mock Get-MgDeviceManagementManagedDevice {
            [PSCustomObject] @{ DeviceName = 'Windows-01'; Id = 'managed-1'; AzureAdDeviceId = 'device-1'; SerialNumber = 'serial-1'; OperatingSystem = 'Windows' }
        }
        Mock Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
            [PSCustomObject] @{ Id = 'autopilot-other'; ManagedDeviceId = 'managed-2'; AzureActiveDirectoryDeviceId = 'device-2'; SerialNumber = 'serial-1' }
        }

        $devices = @(Get-MyDeviceIntune -IncludeAutopilotInventory -Force)

        $devices | Should -HaveCount 1
        $devices[0].AutopilotMatchAmbiguous | Should -BeTrue
        $devices[0].AutopilotDeviceId | Should -Be $null
    }

    It 'marks a managed-device match with contradictory Entra ID as ambiguous' {
        Mock Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
            [PSCustomObject] @{ Id = 'autopilot-other'; ManagedDeviceId = 'managed-1'; AzureActiveDirectoryDeviceId = 'device-2' }
        }

        $devices = @(Get-MyDeviceIntune -IncludeAutopilotInventory -Force)

        $devices | Should -HaveCount 1
        $devices[0].AutopilotMatchAmbiguous | Should -BeTrue
        $devices[0].AutopilotDeviceId | Should -Be $null
    }

    It 'ignores a placeholder managed-device serial when IDs identify one Autopilot record' {
        Mock Get-MgDeviceManagementManagedDevice {
            [PSCustomObject] @{ DeviceName = 'Windows-01'; Id = 'managed-1'; AzureAdDeviceId = 'device-1'; SerialNumber = 'SystemSerialNumber'; OperatingSystem = 'Windows' }
        }
        Mock Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
            [PSCustomObject] @{ Id = 'autopilot-1'; ManagedDeviceId = 'managed-1'; AzureActiveDirectoryDeviceId = 'device-1'; SerialNumber = 'real-serial' }
        }

        $devices = @(Get-MyDeviceIntune -IncludeAutopilotInventory -Force)

        $devices | Should -HaveCount 1
        $devices[0].AutopilotMatchAmbiguous | Should -BeFalse
        $devices[0].AutopilotDeviceId | Should -Be 'autopilot-1'
    }

    It 'ignores a placeholder Autopilot serial when IDs identify one record' {
        Mock Get-MgDeviceManagementManagedDevice {
            [PSCustomObject] @{ DeviceName = 'Windows-01'; Id = 'managed-1'; AzureAdDeviceId = 'device-1'; SerialNumber = 'real-serial'; OperatingSystem = 'Windows' }
        }
        Mock Get-MgDeviceManagementWindowsAutopilotDeviceIdentity {
            [PSCustomObject] @{ Id = 'autopilot-1'; ManagedDeviceId = 'managed-1'; AzureActiveDirectoryDeviceId = 'device-1'; SerialNumber = 'SystemSerialNumber' }
        }

        $devices = @(Get-MyDeviceIntune -IncludeAutopilotInventory -Force)

        $devices | Should -HaveCount 1
        $devices[0].AutopilotMatchAmbiguous | Should -BeFalse
        $devices[0].AutopilotDeviceId | Should -Be 'autopilot-1'
    }

    It 'uses the SDK lifecycle projection when explicitly requested' {
        $script:CapturedManagedDeviceProperties = $null
        Mock Get-MgDeviceManagementManagedDevice {
            param($Property)
            $script:CapturedManagedDeviceProperties = @($Property) -join ','
            [PSCustomObject] @{
                DeviceName = 'iPhone-01'; Id = 'managed-1'; AzureAdDeviceId = 'device-1'
                LastSyncDateTime = [DateTimeOffset]::UtcNow.AddDays(-10)
            }
        }
        Mock Invoke-MgGraphRequest { throw 'REST must not be used for Lifecycle' }

        $devices = @(Get-MyDeviceIntune -PropertySet Lifecycle -Force)

        $devices | Should -HaveCount 1
        $script:CapturedManagedDeviceProperties | Should -Match 'azureADDeviceId'
        $script:CapturedManagedDeviceProperties | Should -Match 'deviceRegistrationState'
        $script:CapturedManagedDeviceProperties | Should -Match 'serialNumber'
        $script:CapturedManagedDeviceProperties | Should -Not -Match 'deviceActionResults'
        $script:CapturedManagedDeviceProperties | Should -Not -Match 'remoteAssistanceSessionUrl'
        $devices[0].LastSeen | Should -BeOfType [DateTimeOffset]
    }

    It 'returns only computer correlation fields for a large synchronized inventory' {
        Mock Invoke-MgGraphRequest {
            if ($Uri -like '*/managedDevices*') {
                return [PSCustomObject] @{ value = @([PSCustomObject] @{
                    azureADDeviceId = 'device-1'; deviceName = 'DEVICE-01'
                    emailAddress = 'owner@example.com'; id = 'managed-1'
                    lastSyncDateTime = '2026-09-01T10:00:00Z'
                    userDisplayName = 'Owner One'; userPrincipalName = 'owner@example.com'
                }) }
            }
            [PSCustomObject] @{ value = @([PSCustomObject] @{
                deviceId = 'device-1'; id = 'entra-1'
                trustType = 'ServerAD'; onPremisesSyncEnabled = $true
            }) }
        }

        $records = @(Get-MyDeviceIntune -Synchronized -PropertySet Computer -Force -ReportProgress 6>&1)
        $devices = @($records | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })
        $progressMessages = @($records | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } | ForEach-Object { [string] $_.MessageData })

        $devices | Should -HaveCount 1
        $devices[0].EntraDeviceObjectId | Should -Be 'entra-1'
        $devices[0].UserPrincipalName | Should -Be 'owner@example.com'
        $devices[0].LastSeenDays | Should -BeGreaterThan 0
        $devices[0].LastSeen | Should -BeOfType [DateTimeOffset]
        $devices[0].PSObject.Properties.Name | Should -Not -Contain 'RemoteAssistanceSessionUrl'
        @($progressMessages | Where-Object { $_ -match 'complete' }) | Should -HaveCount 2
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*/managedDevices*' -and $Uri -like '*$select=azureADDeviceId,deviceName,emailAddress,id,lastSyncDateTime,userDisplayName,userPrincipalName*'
        }
    }

    It 'does not return a partial computer inventory when a later Intune page fails' {
        $script:Devices = @([PSCustomObject] @{
            DeviceId = 'device-1'; Id = 'entra-1'
            OnPremisesSyncEnabled = $true; TrustType = 'ServerAD'
        })
        $script:DevicesDate = Get-Date
        $script:DevicesScope = 'Synchronized'
        Mock Invoke-MgGraphRequest {
            if ($Uri -like '*page2*') { throw 'Intune page two failed' }
            [PSCustomObject] @{
                value = @([PSCustomObject] @{
                    azureADDeviceId = 'device-1'; deviceName = 'DEVICE-01'
                    id = 'managed-1'; lastSyncDateTime = '2026-09-01T10:00:00Z'
                })
                '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?page2'
            }
        }

        $warning = $null
        $devices = @(Get-MyDeviceIntune -Synchronized -PropertySet Computer -WarningAction SilentlyContinue -WarningVariable warning)

        $devices | Should -HaveCount 0
        [string] $warning | Should -Match 'Intune page two failed'
    }

    It 'retains trust and sync metadata for an unfiltered computer inventory' {
        Mock Invoke-MgGraphRequest {
            if ($Uri -like '*/managedDevices*') {
                return [PSCustomObject] @{ value = @([PSCustomObject] @{
                    azureADDeviceId = 'device-1'; deviceName = 'DEVICE-01'
                    id = 'managed-1'; lastSyncDateTime = '2026-09-01T10:00:00Z'
                }) }
            }
            [PSCustomObject] @{ value = @([PSCustomObject] @{
                deviceId = 'device-1'; id = 'entra-1'
                trustType = 'ServerAD'; onPremisesSyncEnabled = $true
            }) }
        }

        $devices = @(Get-MyDeviceIntune -PropertySet Computer -Force)

        $devices | Should -HaveCount 1
        $devices[0].TrustType | Should -Be 'Hybrid AzureAD'
        $devices[0].IsSynchronized | Should -BeTrue
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*/devices?*' -and $Uri -like '*$select=deviceId,id,onPremisesSyncEnabled,trustType*'
        }
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

}
