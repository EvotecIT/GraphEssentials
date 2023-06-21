$Script:Teams = [ordered] @{
    Name       = 'Microsoft Teams Report'
    Enabled    = $true
    Execute    = {
        Get-MyTeam
    }
    Processing = {

    }
    Summary    = {

    }
    Variables  = @{

    }
    Solution   = {
        if ($Script:Reporting['Teams']['Data']) {
            New-HTMLTable -DataTable $Script:Reporting['Teams']['Data'] -Filtering {

            } -ScrollX
        }
    }
}