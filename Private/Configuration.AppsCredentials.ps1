$Script:AppsCredentials = [ordered] @{
    Name       = 'Azure Active Directory Apps Credentials'
    Enabled    = $true
    Execute    = {
        Get-MyAppCredentials
    }
    Processing = {

    }
    Summary    = {

    }
    Variables  = @{

    }
    Solution   = {
        if ($Script:Reporting['AppsCredentials']['Data']) {
            New-HTMLTable -DataTable $Script:Reporting['AppsCredentials']['Data'] -Filtering {
                New-HTMLTableCondition -Name 'Expired' -Operator eq -Value $false -ComparisonType string -BackgroundColor SpringGreen -FailBackgroundColor Salmon
                New-HTMLTableCondition -Name 'DaysToExpire' -Value 30 -Operator 'ge' -BackgroundColor Conifer -ComparisonType number
                New-HTMLTableCondition -Name 'DaysToExpire' -Value 30 -Operator 'lt' -BackgroundColor Orange -ComparisonType number
                New-HTMLTableCondition -Name 'DaysToExpire' -Value 5 -Operator 'lt' -BackgroundColor Red -ComparisonType number
            } -ScrollX
        }
    }
}