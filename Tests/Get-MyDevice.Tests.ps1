BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsPagedInventory.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Resolve-MyDeviceActionTarget.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsObjectProperty.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Get-MyDevice.ps1')

    function Get-MgDevice {
        param([switch] $All, $Property, $ExpandProperty, $ErrorAction)
    }
    function Invoke-MgGraphRequest { param($Method, $Uri, $OutputType, $ErrorAction) }
    function Find-GraphEssentialsAutopilotDevice { $null }
    function Get-GraphEssentialsAutopilotLookup { param([switch] $ReportProgress) $null }
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
                        $null
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

    It 'projects an ambiguous Autopilot association without an identity ID' {
        Mock Get-GraphEssentialsAutopilotLookup { [PSCustomObject] @{ InventoryLoaded = $true } }
        Mock Find-GraphEssentialsAutopilotDevice { [PSCustomObject] @{ Id = $null; MatchAmbiguous = $true } }

        $devices = @(Get-MyDevice -IncludeAutopilotInventory)

        $devices | Should -HaveCount 1
        $devices[0].AutopilotInventoryLoaded | Should -BeTrue
        $devices[0].AutopilotMatchAmbiguous | Should -BeTrue
        $devices[0].AutopilotOnboarded | Should -BeTrue
        $devices[0].AutopilotDeviceId | Should -Be $null
    }

    It 'retains only compact Entra correlation metadata in the shared cache' {
        $devices = @(Get-MyDevice)

        $devices | Should -HaveCount 1
        $devices[0].Name | Should -Be 'DEVICE-01'
        $devices[0].OwnerUserPrincipalName | Should -Be @('user.one@contoso.com')
        $devices[0].OwnerCount | Should -Be 1
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

        $records = @(Get-MyDevice -Synchronized -PropertySet Computer -ReportProgress 6>&1)
        $devices = @($records | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })
        $progressMessages = @($records | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } | ForEach-Object { [string] $_.MessageData })

        $devices | Should -HaveCount 2
        ($progressMessages -join "`n") | Should -Match '2 records across 2 page'
        $devices[0].OwnerDisplayName | Should -Be @('Owner One')
        $devices[0].OwnerUserPrincipalName | Should -Be @('owner@example.com')
        $devices[0].OwnerEnabled | Should -Be @('True')
        $devices[0].EntraDeviceObjectId | Should -Be 'object-1'
        (Resolve-MyDeviceActionTarget -InputObject $devices[0] -TargetType Entra).EntraDeviceObjectId |
            Should -Be 'object-1'
        $devices[1].OwnerDisplayName.Count | Should -Be 0
        $script:requestedUris[0] | Should -Match 'onPremisesSyncEnabled%20eq%20true'
        $script:requestedUris[0] | Should -Match '\$expand=registeredOwners\(\$select=id,displayName,userPrincipalName,accountEnabled\)'
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

    It 'reads the full cloud property set through retrying pages when progress is requested' {
        $script:requestedUris = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-MgGraphRequest {
            $script:requestedUris.Add($Uri)
            if ($Uri -like '*skiptoken*') {
                return [pscustomobject] @{ value = @([pscustomobject] @{
                    deviceId = 'device-2'; id = 'object-2'; displayName = 'Android-02'
                    accountEnabled = $false; operatingSystem = 'Android'; trustType = 'Workplace'
                    registeredOwners = @()
                }) }
            }
            [pscustomobject] @{
                value = @([pscustomobject] @{
                    deviceId = 'device-1'; id = 'object-1'; displayName = 'iPhone-01'
                    accountEnabled = $true; operatingSystem = 'iOS'; trustType = 'Workplace'
                    registrationDateTime = (Get-Date).AddDays(-200).ToString('o')
                    approximateLastSignInDateTime = (Get-Date).AddDays(-120).ToString('o')
                    onPremisesLastSyncDateTime = (Get-Date).AddDays(-30).ToString('o')
                    registeredOwners = @([pscustomobject] @{ displayName = 'Owner One'; accountEnabled = $true; userPrincipalName = 'owner@example.com' })
                })
                '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/devices?$skiptoken=page2'
            }
        }

        $records = @(Get-MyDevice -Type 'AzureAD registered' -PropertySet Full -ReportProgress 6>&1)
        $devices = @($records | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })
        $progress = @($records | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } | ForEach-Object { [string] $_.MessageData })

        $devices | Should -HaveCount 2
        $devices[0].OperatingSystem | Should -Be 'iOS'
        $devices[0].Enabled | Should -BeTrue
        $devices[0].LastSeenDays | Should -BeGreaterThan 100
        $devices[0].FirstSeen | Should -BeOfType [DateTimeOffset]
        $devices[0].LastSeen | Should -BeOfType [DateTimeOffset]
        $devices[0].LastSynchronized | Should -BeOfType [DateTimeOffset]
        $devices[0].OwnerUserPrincipalName | Should -Be @('owner@example.com')
        $devices[1].OperatingSystem | Should -Be 'Android'
        ($progress -join "`n") | Should -Match '2 records across 2 page'
        ($progress -join "`n") | Should -Match 'Graph inventory \(Entra devices\)'
        $script:requestedUris[0] | Should -Match '\$top=200'
        $script:requestedUris[0] | Should -Match '\$select=accountEnabled'
        $script:requestedUris[0] | Should -Match '\$expand=registeredOwners'
        Should -Invoke Get-MgDevice -Times 0 -Exactly
    }

    It 'returns no cloud devices or cache when a later full-inventory page fails after retries' {
        Mock Invoke-MgGraphRequest {
            if ($Uri -like '*skiptoken*') { throw 'Stream does not support reading' }
            [pscustomobject] @{
                value = @([pscustomobject] @{ deviceId = 'device-1'; id = 'object-1'; displayName = 'iPhone-01'; trustType = 'Workplace'; registeredOwners = @() })
                '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/devices?$skiptoken=page2'
            }
        }
        Mock Start-Sleep {}

        $warning = $null
        $devices = @(Get-MyDevice -Type 'AzureAD registered' -PropertySet Full -ReportProgress -WarningAction SilentlyContinue -WarningVariable warning)

        $devices | Should -HaveCount 0
        $script:Devices | Should -BeNullOrEmpty
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
        $devices[0].EntraDeviceObjectId | Should -Be 'object-1'
        $devices[0].OwnerUserPrincipalName | Should -Be @('owner@example.com')
        $devices[0].LastSeenDays | Should -BeGreaterThan 0
        $devices[0].LastSeen | Should -BeOfType [DateTimeOffset]
        $devices[0].LastSynchronized | Should -BeOfType [DateTimeOffset]
        $devices[0].LastSynchronizedDays | Should -BeGreaterThan 0
        $devices[0].PSObject.Properties.Name | Should -Not -Contain 'AutopilotSerialNumber'
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*$select=approximateLastSignInDateTime,deviceId,displayName,id,onPremisesLastSyncDateTime,onPremisesSyncEnabled,trustType*' -and
            $Uri -like '*$expand=registeredOwners($select=id,displayName,userPrincipalName,accountEnabled)*'
        }
    }

    It 'rejects a computer inventory if Graph omits owner account status' {
        Mock Invoke-MgGraphRequest {
            [PSCustomObject] @{ value = @([PSCustomObject] @{
                deviceId = 'device-1'; id = 'object-1'; displayName = 'DEVICE-01'
                onPremisesSyncEnabled = $true; trustType = 'ServerAD'
                registeredOwners = @([PSCustomObject] @{
                    displayName = 'Owner One'; userPrincipalName = 'owner@example.com'
                })
            }) }
        }

        $warning = $null
        $devices = @(Get-MyDevice -PropertySet Computer -WarningAction SilentlyContinue -WarningVariable warning)

        $devices | Should -HaveCount 0
        [string] $warning | Should -Match 'omitted a Boolean accountEnabled'
        $script:Devices | Should -BeNullOrEmpty
    }

    It 'rejects a computer inventory if Graph omits the expanded owner relationship' {
        Mock Invoke-MgGraphRequest {
            [PSCustomObject] @{ value = @([PSCustomObject] @{
                deviceId = 'device-1'; id = 'object-1'; displayName = 'DEVICE-01'
                onPremisesSyncEnabled = $true; trustType = 'ServerAD'
            }) }
        }

        $warning = $null
        $devices = @(Get-MyDevice -PropertySet Computer -WarningAction SilentlyContinue -WarningVariable warning)

        $devices | Should -HaveCount 0
        [string] $warning | Should -Match 'omitted registeredOwners'
        $script:Devices | Should -BeNullOrEmpty
    }

    It 'rejects a computer inventory if Graph returns a null owner relationship' {
        Mock Invoke-MgGraphRequest {
            [PSCustomObject] @{ value = @([PSCustomObject] @{
                deviceId = 'device-1'; id = 'object-1'; displayName = 'DEVICE-01'
                onPremisesSyncEnabled = $true; trustType = 'ServerAD'
                registeredOwners = $null
            }) }
        }

        $warning = $null
        $devices = @(Get-MyDevice -PropertySet Computer -WarningAction SilentlyContinue -WarningVariable warning)

        $devices | Should -HaveCount 0
        [string] $warning | Should -Match 'omitted registeredOwners'
        $script:Devices | Should -BeNullOrEmpty
    }

    It 'rejects a computer inventory if a returned owner has null account status' {
        Mock Invoke-MgGraphRequest {
            [PSCustomObject] @{ value = @([PSCustomObject] @{
                deviceId = 'device-1'; id = 'object-1'; displayName = 'DEVICE-01'
                onPremisesSyncEnabled = $true; trustType = 'ServerAD'
                registeredOwners = @([PSCustomObject] @{
                    displayName = 'Owner One'; accountEnabled = $null
                })
            }) }
        }

        $warning = $null
        $devices = @(Get-MyDevice -PropertySet Computer -WarningAction SilentlyContinue -WarningVariable warning)

        $devices | Should -HaveCount 0
        [string] $warning | Should -Match 'omitted a Boolean accountEnabled'
        $script:Devices | Should -BeNullOrEmpty
    }

    It 'follows an expanded owner continuation before accepting computer inventory' {
        $script:requestedUris = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-MgGraphRequest {
            $script:requestedUris.Add($Uri)
            if ($Uri -like '*/registeredOwners?*') {
                return [PSCustomObject] @{ value = @([PSCustomObject] @{
                    id = 'owner-2'; displayName = 'Owner Two'; accountEnabled = $false
                    userPrincipalName = 'owner.two@example.com'
                }) }
            }
            [PSCustomObject] @{ value = @([PSCustomObject] @{
                deviceId = 'device-1'; id = 'object-1'; displayName = 'DEVICE-01'
                onPremisesSyncEnabled = $true; trustType = 'ServerAD'
                registeredOwners = @([PSCustomObject] @{
                    id = 'owner-1'; displayName = 'Owner One'; accountEnabled = $true
                    userPrincipalName = 'owner.one@example.com'
                })
                'registeredOwners@odata.nextLink' = 'https://graph.microsoft.com/v1.0/devices/object-1/registeredOwners?$skiptoken=owners2'
            }) }
        }

        $records = @(Get-MyDevice -PropertySet Computer -ReportProgress 6>&1)
        $devices = @($records | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })
        $progress = @($records | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } | ForEach-Object { [string] $_.MessageData })

        $devices | Should -HaveCount 1
        $devices[0].OwnerDisplayName | Should -Be @('Owner One', 'Owner Two')
        $devices[0].OwnerEnabled | Should -Be @('True', 'False')
        ($progress -join "`n") | Should -Match 'Graph inventory \(Entra registered owners for object-1\)'
        $script:requestedUris | Should -HaveCount 2
        $script:requestedUris[1] | Should -Be 'https://graph.microsoft.com/v1.0/devices/object-1/registeredOwners?$skiptoken=owners2'
    }

    It 'rejects a possibly truncated owner expansion without a continuation' {
        $owners = @(1..20 | ForEach-Object {
            [PSCustomObject] @{ id = "owner-$_"; accountEnabled = $true }
        })
        Mock Invoke-MgGraphRequest {
            [PSCustomObject] @{ value = @([PSCustomObject] @{
                deviceId = 'device-1'; id = 'object-1'; displayName = 'DEVICE-01'
                onPremisesSyncEnabled = $true; trustType = 'ServerAD'
                registeredOwners = $owners
            }) }
        }

        $warning = $null
        $devices = @(Get-MyDevice -PropertySet Computer -WarningAction SilentlyContinue -WarningVariable warning)

        $devices | Should -HaveCount 0
        [string] $warning | Should -Match 'may have truncated registeredOwners'
        $script:Devices | Should -BeNullOrEmpty
    }

    It 'does not emit an inventory when an expanded owner continuation fails' {
        Mock Invoke-MgGraphRequest {
            if ($Uri -like '*/registeredOwners?*') {
                throw 'owner continuation failed'
            }
            [PSCustomObject] @{ value = @([PSCustomObject] @{
                deviceId = 'device-1'; id = 'object-1'; displayName = 'DEVICE-01'
                onPremisesSyncEnabled = $true; trustType = 'ServerAD'
                registeredOwners = @([PSCustomObject] @{
                    id = 'owner-1'; accountEnabled = $true
                })
                'registeredOwners@odata.nextLink' = 'https://graph.microsoft.com/v1.0/devices/object-1/registeredOwners?$skiptoken=owners2'
            }) }
        }

        $warning = $null
        $devices = @(Get-MyDevice -PropertySet Computer -WarningAction SilentlyContinue -WarningVariable warning)

        $devices | Should -HaveCount 0
        [string] $warning | Should -Match 'owner continuation failed'
        $script:Devices | Should -BeNullOrEmpty
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
