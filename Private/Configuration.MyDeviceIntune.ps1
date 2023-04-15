$Script:DevicesIntune = [ordered] @{
    Name       = 'Azure Active Directory Devices Intune'
    Enabled    = $true
    Execute    = {
        Get-MyDeviceIntune
    }
    Processing = {

    }
    Summary    = {

    }
    Variables  = @{

    }
    Solution   = {
        if ($Script:Reporting['DevicesIntune']['Data']) {
            New-HTMLTable -DataTable $Script:Reporting['DevicesIntune']['Data'] -Filtering {
                New-HTMLTableCondition -Name 'ComplianceState' -Operator eq -Value 'Compliant' -ComparisonType string -BackgroundColor MediumSpringGreen -FailBackgroundColor Cinnabar
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastSeenDays', 'LastSeen'
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastSeenDays', 'LastSeen'
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastSeenDays', 'LastSeen'
                New-HTMLTableCondition -Name 'LastSeenDays' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastSeenDays', 'LastSeen'
            } -ScrollX
        }
    }
}