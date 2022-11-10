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
            } -ScrollX
        }
    }
}