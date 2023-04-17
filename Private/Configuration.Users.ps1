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
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $false -ComparisonType string -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen

                New-HTMLTableCondition -Name 'IsSynchronized' -Operator eq -Value $false -ComparisonType string -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'IsSynchronized' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen

                New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Direct' -ComparisonType string -BackgroundColor LightSkyBlue
                New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Group' -ComparisonType string -BackgroundColor LightGreen
                New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Duplicate' -ComparisonType string -BackgroundColor PeachOrange
                New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Error' -ComparisonType string -BackgroundColor Salmon -HighlightHeaders 'LicensesStatus', 'LicensesErrors'
                New-HTMLTableCondition -Name 'LicensesStatus' -Operator eq -Value '' -ComparisonType string -BackgroundColor OldGold

                New-HTMLTableCondition -Name 'LastPasswordChangeDays' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastPasswordChangeDays', 'LastPasswordChangeDateTime'
                New-HTMLTableCondition -Name 'LastPasswordChangeDays' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastPasswordChangeDays', 'LastPasswordChangeDateTime'
                New-HTMLTableCondition -Name 'LastPasswordChangeDays' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastPasswordChangeDays', 'LastPasswordChangeDateTime'
                New-HTMLTableCondition -Name 'LastPasswordChangeDays' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastPasswordChangeDays', 'LastPasswordChangeDateTime'


                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'

            } -ScrollX
        }
    }
}