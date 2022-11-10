$Script:RolesUsers = [ordered] @{
    Name       = 'Azure Active Directory Roles Users'
    Enabled    = $true
    Execute    = {
        Get-MyRoleUsers -OnlyWithRoles
    }
    Processing = {

    }
    Summary    = {

    }
    Variables  = @{

    }
    Solution   = {
        if ($Script:Reporting['RolesUsers']['Data']) {
            New-HTMLTable -DataTable $Script:Reporting['RolesUsers']['Data'] -Filtering {
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen -FailBackgroundColor Salmon
                New-HTMLTableCondition -Name 'Status' -Operator eq -Value 'Synchronized' -ComparisonType string -BackgroundColor SpringGreen
                New-HTMLTableCondition -Name 'Status' -Operator eq -Value 'Online' -ComparisonType string -BackgroundColor GoldenFizz
            } -ScrollX
        }
    }
}