$Script:Licenses = [ordered] @{
    Name       = 'Azure Licenses'
    Enabled    = $true
    Execute    = {
        Get-MyLicense
    }
    Processing = {

    }
    Summary    = {

    }
    Variables  = @{

    }
    Solution   = {
        if ($Script:Reporting['Licenses']['Data']) {
            New-HTMLTable -DataTable $Script:Reporting['Licenses']['Data'] -Filtering {
                New-HTMLTableCondition -Name 'CapabilityStatus' -Operator eq -Value 'Enabled' -ComparisonType string -BackgroundColor LightGreen -FailBackgroundColor Orange
                New-HTMLTableCondition -Name 'LicensesUsedPercent' -Operator gt -Value 100 -ComparisonType number -BackgroundColor Alizarin -HighlightHeaders 'LicensesUsedCount', 'LicensesUsedPercent'
                New-HTMLTableCondition -Name 'LicensesUsedPercent' -Operator eq -Value 100 -ComparisonType number -BackgroundColor Salmon -HighlightHeaders 'LicensesUsedCount', 'LicensesUsedPercent'
                New-HTMLTableCondition -Name 'LicensesUsedPercent' -Operator betweenInclusive -Value 70, 99 -ComparisonType number -BackgroundColor Orange -HighlightHeaders 'LicensesUsedCount', 'LicensesUsedPercent'
                New-HTMLTableCondition -Name 'LicensesUsedPercent' -Operator betweenInclusive -Value 40, 69 -ComparisonType number -BackgroundColor LightSkyBlue -HighlightHeaders 'LicensesUsedCount', 'LicensesUsedPercent'
                New-HTMLTableCondition -Name 'LicensesUsedPercent' -Operator betweenInclusive -Value 1, 39 -ComparisonType number -BackgroundColor Almond -HighlightHeaders 'LicensesUsedCount', 'LicensesUsedPercent'
                New-HTMLTableCondition -Name 'LicensesUsedPercent' -Operator eq -Value 0 -ComparisonType number -BackgroundColor LightGreen -HighlightHeaders 'LicensesUsedCount', 'LicensesUsedPercent'
            } -ScrollX
        }
    }
}