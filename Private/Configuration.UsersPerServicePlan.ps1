$Script:UsersPerServicePlan = [ordered] @{
    Name       = 'Azure Active Directory Users Per Service Plan'
    Enabled    = $true
    Execute    = {
        Get-MyUser -PerServicePlan
    }
    Processing = {

    }
    Summary    = {

    }
    Variables  = @{

    }
    Solution   = {
        if ($Script:Reporting['UsersPerServicePlan']['Data']) {
            New-HTMLTable -DataTable $Script:Reporting['UsersPerServicePlan']['Data'] -Filtering {
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $false -ComparisonType string -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen
            } -ScrollX
        }
    }
}
