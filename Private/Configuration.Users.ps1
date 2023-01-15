$Script:Users = [ordered] @{
    Name       = 'Azure Active Directory Users'
    Enabled    = $true
    Execute    = {
        Get-MyUser
    }
    Processing = {

    }
    Summary    = {

    }
    Variables  = @{

    }
    Solution   = {
        if ($Script:Reporting['Users']['Data']) {
            New-HTMLTable -DataTable $Script:Reporting['Users']['Data'] -Filtering {
                New-HTMLTableCondition -Name 'AccountEnabled' -Operator eq -Value $false -ComparisonType string -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'AccountEnabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen

                New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Direct' -ComparisonType string -BackgroundColor LightSkyBlue
                New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Group' -ComparisonType string -BackgroundColor LightGreen
                New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Duplicate' -ComparisonType string -BackgroundColor PeachOrange
                New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Error' -ComparisonType string -BackgroundColor Salmon -HighlightHeaders 'LicensesStatus', 'LicensesErrors'
                New-HTMLTableCondition -Name 'LicensesStatus' -Operator eq -Value '' -ComparisonType string -BackgroundColor OldGold
            } -ScrollX
        }
    }
}