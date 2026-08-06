BeforeAll {
    . (Join-Path $PSScriptRoot '..\Public\Get-MyDevice.ps1')

    function Get-MgDevice {
        param([switch] $All, $Property, $ExpandProperty, $ErrorAction)
    }
    function Find-GraphEssentialsAutopilotDevice { $null }
    function Get-GraphEssentialsAutopilotLookup { $null }
}

Describe 'Get-MyDevice' {
    BeforeEach {
        $script:Devices = $null
        $script:DevicesDate = $null

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
}
