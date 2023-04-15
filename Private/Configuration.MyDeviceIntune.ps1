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

            } -ScrollX
        }
    }
}