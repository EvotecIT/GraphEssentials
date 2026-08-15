BeforeAll {
    function Get-MyUser {
        param(
            [switch] $PerLicense,
            [switch] $PerServicePlan,
            [switch] $IncludeSignInActivity
        )
    }

    function Get-MyGuest {
        param([switch] $IncludeSignInActivity)
    }

    . (Join-Path $PSScriptRoot '..\Private\Configuration.Users.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Configuration.UsersPerLicense.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Configuration.UsersPerServicePlan.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Configuration.Guests.ps1')
}

Describe 'Sign-in activity consumer contracts' {
    BeforeEach {
        Mock Get-MyUser
        Mock Get-MyGuest
    }

    It 'keeps the built-in user security report opted in' {
        & $Script:Users.Execute

        Should -Invoke Get-MyUser -Times 1 -Exactly -ParameterFilter { $IncludeSignInActivity }
    }

    It 'keeps the built-in per-license report opted in' {
        & $Script:UsersPerLicense.Execute

        Should -Invoke Get-MyUser -Times 1 -Exactly -ParameterFilter { $PerLicense -and $IncludeSignInActivity }
    }

    It 'keeps the built-in per-service-plan report opted in' {
        & $Script:UsersPerServicePlan.Execute

        Should -Invoke Get-MyUser -Times 1 -Exactly -ParameterFilter { $PerServicePlan -and $IncludeSignInActivity }
    }

    It 'keeps the built-in guest security report opted in' {
        & $Script:Guests.Execute

        Should -Invoke Get-MyGuest -Times 1 -Exactly -ParameterFilter { $IncludeSignInActivity }
    }

    It 'does not classify sign-in metadata as licenses' {
        $Script:Reporting = @{
            UsersPerLicense = @{
                Data = @([PSCustomObject]@{
                        DisplayName                     = 'User One'
                        Enabled                         = $true
                        UserType                        = 'Member'
                        IsSynchronized                  = $true
                        LastSuccessfulSignInDateTime    = Get-Date
                        LastSuccessfulSignInDaysAgo     = 1
                        NeverSuccessfullySignedIn       = $false
                        SignInPattern                   = 'Interactive only'
                        SignInActivityRequested         = $true
                        SignInActivityAvailable         = $true
                        DifferentLicense                = @()
                        LicensesErrors                  = @()
                        'Microsoft 365 E3'              = @('Direct')
                    })
            }
        }

        $summary = & $Script:UsersPerLicense.Summary
        $names = @($summary.LicenseAssignmentSummary.License)

        $names | Should -Contain 'Microsoft 365 E3'
        $names | Should -Not -Contain 'LastSuccessfulSignInDateTime'
        $names | Should -Not -Contain 'LastSuccessfulSignInDaysAgo'
        $names | Should -Not -Contain 'NeverSuccessfullySignedIn'
        $names | Should -Not -Contain 'SignInPattern'
    }

    It 'does not classify sign-in metadata as service plans' {
        $Script:Reporting = @{
            UsersPerServicePlan = @{
                Data = @([PSCustomObject]@{
                        DisplayName                     = 'User One'
                        Enabled                         = $true
                        UserType                        = 'Member'
                        IsSynchronized                  = $true
                        LastSignInDaysAgo               = 1
                        LastSuccessfulSignInDateTime    = Get-Date
                        LastSuccessfulSignInDaysAgo     = 1
                        NeverSignedIn                   = $false
                        NeverSuccessfullySignedIn       = $false
                        SignInPattern                   = 'Interactive only'
                        SignInActivityRequested         = $true
                        SignInActivityAvailable         = $true
                        DeletedServicePlans             = @()
                        'Exchange Online'               = 'Assigned'
                    })
            }
        }

        $summary = & $Script:UsersPerServicePlan.Summary
        $names = @($summary.ServicePlanSummary.ServicePlan)

        $names | Should -Contain 'Exchange Online'
        $names | Should -Not -Contain 'LastSuccessfulSignInDateTime'
        $names | Should -Not -Contain 'LastSuccessfulSignInDaysAgo'
        $names | Should -Not -Contain 'NeverSuccessfullySignedIn'
        $names | Should -Not -Contain 'SignInPattern'
    }
}
