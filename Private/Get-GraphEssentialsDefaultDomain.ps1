function Get-GraphEssentialsDefaultDomain {
    [CmdletBinding()]
    param()

    try {
        $org = Get-MgOrganization -Property VerifiedDomains -ErrorAction Stop
        if ($org -and $org.VerifiedDomains) {
            $default = $org.VerifiedDomains | Where-Object { $_.IsDefault -eq $true }
            if ($default) { $default[0].Name }
            else { ($org.VerifiedDomains | Select-Object -First 1).Name }
        }
    } catch {
        # No default domain available (insufficient permissions or other error)
        $null
    }
}

