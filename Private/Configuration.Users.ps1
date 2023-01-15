﻿$Script:Users = [ordered] @{
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
                # New-HTMLTableCondition -Name 'DescriptionWithEmail' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen -FailBackgroundColor Salmon
                # New-HTMLTableCondition -Name 'KeysCount' -Operator gt -Value 1 -ComparisonType number -BackgroundColor GoldenFizz
                # New-HTMLTableCondition -Name 'KeysCount' -Operator eq -Value 0 -ComparisonType number -BackgroundColor Salmon -Row
                # New-HTMLTableCondition -Name 'KeysCount' -Operator eq -Value 1 -ComparisonType number -BackgroundColor SpringGreen
                # New-HTMLTableCondition -Name 'Expired' -Operator eq -Value "No" -ComparisonType string -BackgroundColor SpringGreen
                # New-HTMLTableCondition -Name 'Expired' -Operator eq -Value "Yes" -ComparisonType string -BackgroundColor Salmon -Row
                # New-HTMLTableCondition -Name 'Expired' -Operator eq -Value "Not available" -ComparisonType string -BackgroundColor Salmon -Row
            } -ScrollX
        }
    }
}