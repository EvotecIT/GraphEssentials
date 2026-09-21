BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsPagedInventory.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Get-MyDevice.ps1')

    function Get-MgDevice {
        param([switch] $All, $Property, $ExpandProperty, $ErrorAction)
    }
    function Invoke-MgGraphRequest { param($Method, $Uri, $OutputType, $ErrorAction) }
    function Find-GraphEssentialsAutopilotDevice { $null }
    function Get-GraphEssentialsAutopilotLookup { $null }
}

Describe 'Get-MyDevice' {
    BeforeEach {
        $script:Devices = $null
        $script:DevicesDate = $null
        $script:DevicesScope = $null

        Mock Get-MgDevice {
            @(
                [PSCustomObject] @{
                    AccountEnabled                = $true
                    ApproximateLastSignInDateTime = (Get-Date).AddDays(-10)
                    DeviceId                      = 'device-1'
                    DisplayName                   = 'DEVICE-01'
                    Id                            = 'object-1'
                    OnPremisesSyncEnabled         = $false
                    OperatingSystem               = 'Windows'
                    RegisteredOwners              = @(
                        [PSCustomObject] @{
                            AdditionalProperties = @{
                                accountEnabled    = $true
                                displayName       = 'User One'
                                userPrincipalName = 'user.one@contoso.com'
                            }
                        }
                    )
                    TrustType                     = 'Workplace'
                }
            )
        }
    }

    It 'retains only compact Entra correlation metadata in the shared cache' {
        $devices = @(Get-MyDevice)

        $devices | Should -HaveCount 1
        $devices[0].Name | Should -Be 'DEVICE-01'
        $devices[0].OwnerUserPrincipalName | Should -Be @('user.one@contoso.com')
        @($script:Devices) | Should -HaveCount 1
        $script:Devices[0].PSObject.Properties.Name | Should -Be @(
            'DeviceId'
            'Id'
            'OnPremisesSyncEnabled'
            'TrustType'
        )
        $script:Devices[0].PSObject.Properties.Name | Should -Not -Contain 'RegisteredOwners'
        $script:DevicesDate | Should -Not -BeNullOrEmpty
    }

    It 'does not expand owner metadata for devices excluded by join type' {
        $additionalProperties = [PSCustomObject] @{}
        $additionalProperties | Add-Member -MemberType ScriptProperty -Name displayName -Value { throw 'owner metadata should not be read' }
        Mock Get-MgDevice {
            @(
                [PSCustomObject] @{
                    DeviceId          = 'device-filtered'
                    Id                = 'object-filtered'
                    RegisteredOwners  = @([PSCustomObject] @{ AdditionalProperties = $additionalProperties })
                    TrustType         = 'Workplace'
                }
            )
        }

        $devices = @(Get-MyDevice -Type 'AzureAD joined')

        $devices | Should -HaveCount 0
        @($script:Devices) | Should -HaveCount 1
    }

    It 'does not emit a partial inventory or cache when Graph enumeration fails' {
        Mock Get-MgDevice {
            [PSCustomObject] @{
                DeviceId         = 'device-partial'
                DisplayName      = 'PARTIAL'
                Id               = 'object-partial'
                RegisteredOwners = @()
                TrustType        = 'Workplace'
            }
            throw 'page two failed'
        }

        $warning = $null
        $devices = @(Get-MyDevice -WarningAction SilentlyContinue -WarningVariable warning)

        $devices | Should -HaveCount 0
        $script:Devices | Should -BeNullOrEmpty
        $script:DevicesDate | Should -BeNullOrEmpty
        [string] $warning | Should -Match 'page two failed'
    }

    It 'reads synchronized devices across pages with a server filter and owner details' {
        $script:requestedUris = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-MgGraphRequest {
            $script:requestedUris.Add($Uri)
            if ($script:requestedUris.Count -eq 1) {
                return [PSCustomObject] @{
                    value = @([PSCustomObject] @{
                        deviceId = 'device-1'; id = 'object-1'; displayName = 'DEVICE-01'
                        onPremisesSyncEnabled = $true; trustType = 'ServerAd'
                        registeredOwners = @([PSCustomObject] @{
                            displayName = 'Owner One'; accountEnabled = $true
                            userPrincipalName = 'owner@example.com'
                        })
                    })
                    '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/devices?$skiptoken=page2'
                }
            }
            [PSCustomObject] @{
                value = @([PSCustomObject] @{
                    deviceId = 'device-2'; id = 'object-2'; displayName = 'DEVICE-02'
                    onPremisesSyncEnabled = $true; trustType = 'ServerAd'
                    registeredOwners = @()
                })
            }
        }

        $devices = @(Get-MyDevice -Synchronized -PropertySet Computer)

        $devices | Should -HaveCount 2
        $devices[0].OwnerDisplayName | Should -Be @('Owner One')
        $devices[0].OwnerUserPrincipalName | Should -Be @('owner@example.com')
        $devices[1].OwnerDisplayName.Count | Should -Be 0
        $script:requestedUris[0] | Should -Match 'onPremisesSyncEnabled%20eq%20true'
        $script:requestedUris[0] | Should -Match '\$expand=registeredOwners'
        $script:requestedUris[1] | Should -Be 'https://graph.microsoft.com/v1.0/devices?$skiptoken=page2'
        @($script:Devices) | Should -HaveCount 2
        $script:DevicesScope | Should -Be 'Synchronized'
    }

    It 'does not return a partial synchronized inventory after a later page fails' {
        Mock Invoke-MgGraphRequest {
            if ($Uri -like '*skiptoken*') {
                throw 'The request was canceled due to the configured HttpClient.Timeout of 300 seconds elapsing.'
            }
            [PSCustomObject] @{
                value = @([PSCustomObject] @{
                    deviceId = 'device-1'; id = 'object-1'; displayName = 'DEVICE-01'
                    onPremisesSyncEnabled = $true; trustType = 'ServerAd'
                    registeredOwners = @()
                })
                '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/devices?$skiptoken=page2'
            }
        }
        Mock Start-Sleep {}

        $warning = $null
        $devices = @(Get-MyDevice -Synchronized -PropertySet Computer -WarningAction SilentlyContinue -WarningVariable warning)

        $devices | Should -HaveCount 0
        $script:Devices | Should -BeNullOrEmpty
        $script:DevicesScope | Should -BeNullOrEmpty
        [string] $warning | Should -Match 'page 2 failed after 3 attempt'
        Should -Invoke Invoke-MgGraphRequest -Times 4 -Exactly
    }

    It 'returns a compact computer projection with dates and owners' {
        Mock Invoke-MgGraphRequest {
            [PSCustomObject] @{ value = @([PSCustomObject] @{
                deviceId = 'device-1'; id = 'object-1'; displayName = 'DEVICE-01'
                onPremisesSyncEnabled = $true; trustType = 'ServerAd'
                approximateLastSignInDateTime = '2026-09-01T10:00:00Z'
                onPremisesLastSyncDateTime = '2026-09-02T10:00:00Z'
                registeredOwners = @([PSCustomObject] @{
                    displayName = 'Owner One'; accountEnabled = $true
                    userPrincipalName = 'owner@example.com'
                })
            }) }
        }

        $devices = @(Get-MyDevice -Synchronized -PropertySet Computer)

        $devices | Should -HaveCount 1
        $devices[0].Name | Should -Be 'DEVICE-01'
        $devices[0].OwnerUserPrincipalName | Should -Be @('owner@example.com')
        $devices[0].LastSeenDays | Should -BeGreaterThan 0
        $devices[0].LastSeen | Should -BeOfType [DateTimeOffset]
        $devices[0].LastSynchronized | Should -BeOfType [DateTimeOffset]
        $devices[0].LastSynchronizedDays | Should -BeGreaterThan 0
        $devices[0].PSObject.Properties.Name | Should -Not -Contain 'AutopilotSerialNumber'
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*$select=approximateLastSignInDateTime,deviceId,displayName,id,onPremisesLastSyncDateTime,onPremisesSyncEnabled,trustType*' -and
            $Uri -like '*$expand=registeredOwners*'
        }
    }

    It 'preserves SDK output types for existing synchronized full requests' {
        Mock Get-MgDevice {
            [PSCustomObject] @{
                DeviceId = 'device-1'; Id = 'object-1'; DisplayName = 'DEVICE-01'
                OnPremisesSyncEnabled = $true; TrustType = 'ServerAD'
                ApproximateLastSignInDateTime = [DateTimeOffset]::UtcNow.AddDays(-1)
                RegisteredOwners = @()
            }
        }
        Mock Invoke-MgGraphRequest { throw 'REST must not be used for Full' }

        $devices = @(Get-MyDevice -Synchronized)

        $devices | Should -HaveCount 1
        $devices[0].LastSeen | Should -BeOfType [DateTimeOffset]
        $script:DevicesScope | Should -Be 'All'
        Should -Invoke Get-MgDevice -Times 1 -Exactly
    }
}
