$Script:UsersPerLicense = [ordered] @{
    Name       = 'Azure Active Directory Users Per License'
    Enabled    = $true
    Execute    = {
        Get-MyUser -PerLicense
    }
    Processing = {

    }
    Summary    = {

    }
    Variables  = @{

    }
    Solution   = {
        if ($Script:Reporting['UsersPerLicense']['Data']) {
            New-HTMLTable -DataTable $Script:Reporting['UsersPerLicense']['Data'] -Filtering {
                New-HTMLTableCondition -Name 'AccountEnabled' -Operator eq -Value $false -ComparisonType string -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'AccountEnabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen

                foreach ($Name in $Script:Reporting['UsersPerLicense']['Data'][0].PSObject.Properties.Name) {
                    if ($Name -notin 'DisplayName', 'Id', 'Enabled', 'UserPrincipalName', 'AccountEnabled', 'Mail' , 'Manager', 'LicensesStatus', 'LicensesErrors', 'Surname', 'LastPasswordChangeDateTime', 'GivenName', 'JobTitle') {
                        New-HTMLTableCondition -Name $Name -Operator eq -Value 'Direct' -ComparisonType string -BackgroundColor GoldenFizz
                        New-HTMLTableCondition -Name $Name -Operator eq -Value 'Group' -ComparisonType string -BackgroundColor LightGreen
                        New-HTMLTableConditionGroup -Conditions {
                            New-HTMLTableCondition -Name $Name -Operator ne -Value 'Group' -ComparisonType string
                            New-HTMLTableCondition -Name $Name -Operator ne -Value 'Direct' -ComparisonType string
                            New-HTMLTableCondition -Name $Name -Operator ne -Value '' -ComparisonType string
                        } -Logic AND -BackgroundColor Orange -HighlightHeaders $Name
                    }
                }
            } -ScrollX
        }
    }
}