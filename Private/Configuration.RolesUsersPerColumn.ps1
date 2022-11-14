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
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $false -ComparisonType string -BackgroundColor Salmon
                foreach ($Name in $Script:Reporting['RolesUsersPerColumn']['Data'][0].PSObject.Properties.Name) {
                    if ($Name -notin 'Name', 'Enabled', 'UserPrincipalName', 'Mail' , 'Status', 'Type', 'Location', 'CreatedDateTime') {
                        New-HTMLTableCondition -Name $Name -Operator eq -Value 'Direct' -ComparisonType string -BackgroundColor GoldenFizz
                        New-HTMLTableCondition -Name $Name -Operator eq -Value 'Eligible' -ComparisonType string -BackgroundColor SpringGreen
                        New-HTMLTableConditionGroup -Conditions {
                            New-HTMLTableCondition -Name $Name -Operator ne -Value 'Eligible' -ComparisonType string
                            New-HTMLTableCondition -Name $Name -Operator ne -Value 'Direct' -ComparisonType string
                            New-HTMLTableCondition -Name $Name -Operator ne -Value '' -ComparisonType string
                        } -Logic AND -BackgroundColor Orange -HighlightHeaders $Name
                    }
                }
                New-HTMLTableCondition -Name 'Status' -Operator eq -Value 'Synchronized' -ComparisonType string -BackgroundColor SpringGreen
                New-HTMLTableCondition -Name 'Status' -Operator eq -Value 'Online' -ComparisonType string -BackgroundColor GoldenFizz
            } -ScrollX
        }
    }
}