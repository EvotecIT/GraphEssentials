$Script:RolesUsersPerColumn = [ordered] @{
    Name       = 'Azure Active Directory Roles Users Per Column'
    Enabled    = $true
    Execute    = {
        Get-MyRoleUsers -OnlyWithRoles -RolePerColumn
    }
    Processing = {

    }
    Summary    = {

    }
    Variables  = @{

    }
    Solution   = {
        if ($Script:Reporting['RolesUsersPerColumn']['Data']) {
            New-HTMLTable -DataTable $Script:Reporting['RolesUsersPerColumn']['Data'] -Filtering {
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor GreenLeaf -FailBackgroundColor Salmon
            } -ScrollX
        }
    }
}