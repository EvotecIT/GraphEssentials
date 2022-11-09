$Script:Roles = [ordered] @{
    Name       = 'Azure Active Directory Roles'
    Enabled    = $true
    Execute    = {
        Get-MyRole -OnlyWithMembers
    }
    Processing = {

    }
    Summary    = {

    }
    Variables  = @{

    }
    Solution   = {
        if ($Script:Reporting['Roles']['Data']) {
            New-HTMLTable -DataTable $Script:Reporting['Roles']['Data'] -Filtering {
                New-HTMLTableCondition -Name 'IsEnabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor GreenLeaf -FailBackgroundColor Salmon
            }
        }
    }
}