BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsObjectValue.ps1')
    . (Join-Path $PSScriptRoot '..\Private\ConvertTo-GraphEssentialsDirectoryUser.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Get-MyDirectoryUser.ps1')
    function Get-MgUser {
        [CmdletBinding()]
        param($UserId, [switch] $All, $Property, $Filter, $Sort, $CountVariable, $ConsistencyLevel, $ExpandProperty)
    }
}

Describe 'Directory user automation projection' {
    BeforeEach {
        Mock Get-MgUser {
            [pscustomobject] @{
                Id = 'user-1'
                DisplayName = 'User One'
                AccountEnabled = $false
                BusinessPhones = [string[]] @()
                Mail = $null
                Manager = [pscustomobject] @{
                    Id = 'manager-1'
                    AdditionalProperties = @{
                        displayName = 'Manager One'
                        userPrincipalName = 'manager@example.com'
                        onPremisesSyncEnabled = $false
                    }
                }
                OnPremisesExtensionAttributes = [pscustomobject] @{ ExtensionAttribute1 = 'Division One' }
                AdditionalProperties = @{ extension_appid_CostCenter = 'CC-42' }
            }
        }
    }

    It 'preserves selected false null empty-array and custom-extension values without SDK plumbing' {
        $user = Get-MyDirectoryUser -Property AccountEnabled, Mail, BusinessPhones, extension_appid_CostCenter
        $user.Id | Should -Be 'user-1'
        $user.AccountEnabled | Should -BeFalse
        $user.PSObject.Properties.Name | Should -Contain 'Mail'
        $user.Mail | Should -BeNullOrEmpty
        $user.BusinessPhones.GetType().IsArray | Should -BeTrue
        $user.BusinessPhones.Count | Should -Be 0
        $user.extension_appid_CostCenter | Should -Be 'CC-42'
        $user.PSObject.Properties.Name | Should -Not -Contain 'AdditionalProperties'
        $user.PSObject.Properties.Name | Should -Not -Contain 'DisplayName'
        Should -Invoke Get-MgUser -Times 1 -Exactly -ParameterFilter { $All -and $Property -contains 'Id' }
    }

    It 'projects nested manager identity and additional fields when Manager is selected' {
        $user = Get-MyDirectoryUser -Property Id, Manager
        $user.Manager.Id | Should -Be 'manager-1'
        $user.Manager.DisplayName | Should -Be 'Manager One'
        $user.Manager.UserPrincipalName | Should -Be 'manager@example.com'
        $user.Manager.OnPremisesSyncEnabled | Should -BeFalse
        Should -Invoke Get-MgUser -Times 1 -Exactly -ParameterFilter { $ExpandProperty -like 'manager(*' -and $Property -notcontains 'Manager' }
    }

    It 'flattens requested on-premises extension aliases while preserving an explicitly selected nested value' {
        $user = Get-MyDirectoryUser -Property extensionAttribute1, extensionAttribute2, OnPremisesExtensionAttributes
        $user.extensionAttribute1 | Should -Be 'Division One'
        $user.extensionAttribute2 | Should -BeNullOrEmpty
        $user.OnPremisesExtensionAttributes.ExtensionAttribute1 | Should -Be 'Division One'
        Should -Invoke Get-MgUser -Times 1 -Exactly -ParameterFilter {
            @($Property | Where-Object { $_ -ieq 'OnPremisesExtensionAttributes' }).Count -eq 1 -and $Property -notcontains 'extensionAttribute1'
        }
    }

    It 'uses SDK single-user lookup and returns a null manager when none is assigned' {
        Mock Get-MgUser { [pscustomobject] @{ Id = 'user-2'; Manager = $null } }
        $user = Get-MyDirectoryUser -UserId 'user@example.com' -Property Id -IncludeManager
        $user.Id | Should -Be 'user-2'
        $user.Manager | Should -BeNullOrEmpty
        Should -Invoke Get-MgUser -Times 1 -Exactly -ParameterFilter { $UserId -eq 'user@example.com' -and -not $All }
    }

    It 'forwards a complete filtered sorted advanced query and SDK count-variable contract' {
        $null = Get-MyDirectoryUser -Filter "startsWith(displayName,'A')" -Sort DisplayName -CountVariable matchingDirectoryUsers
        Should -Invoke Get-MgUser -Times 1 -Exactly -ParameterFilter {
            $All -and $Filter -eq "startsWith(displayName,'A')" -and $Sort -contains 'DisplayName' -and
            $CountVariable -eq 'matchingDirectoryUsers' -and $ConsistencyLevel -eq 'eventual'
        }
    }

    It 'rejects unsupported manager expansion with an advanced query before requesting data' {
        { Get-MyDirectoryUser -IncludeManager -CountVariable matchingUsers } | Should -Throw '*manager expansion*'
        Should -Invoke Get-MgUser -Times 0 -Exactly
    }

    It 'emits no partial inventory when a later SDK page fails' {
        Mock Get-MgUser {
            [pscustomobject] @{ Id = 'first-page-user' }
            throw 'second page unavailable'
        }
        $observed = [System.Collections.Generic.List[object]]::new()
        { Get-MyDirectoryUser | ForEach-Object { $observed.Add($_) } } | Should -Throw '*second page unavailable*'
        $observed.Count | Should -Be 0
    }

    It 'rejects an inventory of <Returned> users below MinimumCount before emitting records' -ForEach @(
        @{ Returned = 0; Required = 1 }
        @{ Returned = 1; Required = 2 }
    ) {
        Mock Get-MgUser {
            for ($index = 0; $index -lt $Returned; $index++) {
                [pscustomobject] @{ Id = 'user-' + $index }
            }
        }
        $observed = [System.Collections.Generic.List[object]]::new()
        { Get-MyDirectoryUser -MinimumCount $Required | ForEach-Object { $observed.Add($_) } } | Should -Throw '*fewer than MinimumCount*'
        $observed.Count | Should -Be 0
    }

    It 'returns the selected records when the complete inventory meets MinimumCount' {
        $users = @(Get-MyDirectoryUser -MinimumCount 1 -Property AccountEnabled)
        $users.Count | Should -Be 1
        $users[0].Id | Should -Be 'user-1'
        $users[0].AccountEnabled | Should -BeFalse
        $users[0].PSObject.Properties.Name | Should -Not -Contain 'DisplayName'
    }
}
