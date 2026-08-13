BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Resolve-GraphEssentialsUserLicenseAssignments.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Get-MyUser.ps1')

    function Get-MyLicense {
        param([switch] $Internal)
    }

    function Get-MgUser {
        param(
            [switch] $All,
            [string[]] $Property,
            [string[]] $ExpandProperty
        )
    }

    function Stop-TimeLog {
        param($Time, $Option)
        '0 seconds'
    }
}

Describe 'Get-MyUser license projection' {
    BeforeEach {
        $script:SkuId = [Guid] '11111111-1111-1111-1111-111111111111'
        $script:LicenseLookup = [ordered] @{}
        $script:LicenseLookup[$script:SkuId] = 'Microsoft 365 E3'

        Mock Get-MyLicense {
            [ordered] @{
                Licenses     = $script:LicenseLookup
                ServicePlans = [ordered] @{}
            }
        }

        Mock Get-MgUser {
            [PSCustomObject] @{
                AccountEnabled                  = $true
                AssignedLicenses                = @([PSCustomObject] @{ SkuId = $script:SkuId })
                AssignedPlans                   = @()
                CreatedDateTime                 = $null
                DisplayName                     = 'Licensed User'
                GivenName                       = 'Licensed'
                Id                              = 'user-1'
                JobTitle                        = $null
                LastPasswordChangeDateTime      = $null
                LicenseAssignmentStates         = @()
                Mail                            = 'licensed@contoso.com'
                Manager                         = $null
                OnPremisesDistinguishedName     = $null
                OnPremisesLastSyncDateTime      = $null
                OnPremisesSyncEnabled           = $null
                SignInActivity                  = $null
                SurName                         = 'User'
                UserPrincipalName               = 'licensed@contoso.com'
                UserType                        = 'Member'
            }
        }
    }

    It 'falls back to AssignedLicenses when detailed assignment state is empty' {
        $result = Get-MyUser

        $result.HasLicenses | Should -BeTrue
        $result.LicenseCount | Should -Be 1
        $result.Licenses | Should -Contain 'Microsoft 365 E3'
        $result.LicensesStatus | Should -Contain 'Assigned'
    }

    It 'uses detailed assignment state without duplicating the AssignedLicenses entry' {
        Mock Get-MgUser {
            [PSCustomObject] @{
                AccountEnabled                  = $true
                AssignedLicenses                = @([PSCustomObject] @{ SkuId = $script:SkuId })
                AssignedPlans                   = @()
                DisplayName                     = 'Licensed User'
                Id                              = 'user-1'
                LicenseAssignmentStates         = @([PSCustomObject] @{
                        AssignedByGroup = $null
                        Error           = $null
                        SkuId           = $script:SkuId
                        State           = 'Active'
                    })
                Mail                            = 'licensed@contoso.com'
                Manager                         = $null
                OnPremisesSyncEnabled           = $null
                SignInActivity                  = $null
                UserPrincipalName               = 'licensed@contoso.com'
                UserType                        = 'Member'
            }
        }

        $result = Get-MyUser

        $result.LicenseCount | Should -Be 1
        $result.LicensesStatus | Should -Contain 'Direct'
        $result.LicensesStatus | Should -Not -Contain 'Assigned'
    }

    It 'keeps an assigned SKU visible when the tenant SKU lookup lacks its display name' {
        $script:LicenseLookup.Clear()

        $result = Get-MyUser -WarningAction SilentlyContinue

        $result.HasLicenses | Should -BeTrue
        $result.Licenses | Should -Contain ([string] $script:SkuId)
        $result.LicensesErrors | Should -Contain "License ID $($script:SkuId) not found in All Licenses"
    }

    It 'uses AssignedLicenses fallback in the per-license projection' {
        $result = Get-MyUser -PerLicense

        $result.'Microsoft 365 E3' | Should -Contain 'Assigned'
    }
}
