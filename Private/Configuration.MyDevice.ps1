$Script:Devices = [ordered] @{
    Name       = 'Azure Active Directory Devices'
    Enabled    = $true
    Execute    = {
        Get-MyDevice
    }
    Processing = {

    }
    Summary    = {

    }
    Variables  = @{

    }
    Solution   = {
        if ($Script:Reporting['Devices']['Data']) {
            New-HTMLTable -DataTable $Script:Reporting['Devices']['Data'] -Filtering {
                New-HTMLTableCondition -Name 'Enabled' -Value $true -Operator eq -ComparisonType string -BackgroundColor MediumSpringGreen
                New-HTMLTableCondition -Name 'Enabled' -Value $false -Operator eq -ComparisonType string -BackgroundColor Cinnabar
                New-HTMLTableCondition -Name 'IsManaged' -Value $true -Operator eq -ComparisonType string -BackgroundColor MediumSpringGreen
                New-HTMLTableCondition -Name 'IsManaged' -Value $false -Operator eq -ComparisonType string -BackgroundColor Cinnabar
                New-HTMLTableCondition -Name 'IsCompliant' -Value $true -Operator eq -ComparisonType string -BackgroundColor MediumSpringGreen
                New-HTMLTableCondition -Name 'IsCompliant' -Value $false -Operator eq -ComparisonType string -BackgroundColor Cinnabar
                New-HTMLTableCondition -Name 'IsSynchronized' -Value $true -Operator eq -ComparisonType string -BackgroundColor MediumSpringGreen
                New-HTMLTableCondition -Name 'IsSynchronized' -Value $false -Operator eq -ComparisonType string -BackgroundColor Cinnabar
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastSeenDays', 'LastSeen'
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastSeenDays', 'LastSeen'
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastSeenDays', 'LastSeen'
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastSeenDays', 'LastSeen'
                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
            } -ScrollX
        }
    }
}