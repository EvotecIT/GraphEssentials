function Test-Fido2Registration {
    [CmdletBinding()]
    param (
        [string]$UPN,
        [string]$DisplayName
    )
    try {
        $RegisteredKey = Get-MgUserAuthenticationFido2Method -UserId $UPN | Where-Object { $_.DisplayName -eq $DisplayName }
        if ($RegisteredKey) {
            Write-Verbose -Message "Passkey registered successfully for user $UPN."
        } else {
            Write-Warning -Message "Failed to verify the registration of the passkey."
        }
    } catch {
        Write-Warning -Message "Failed to verify the registration: $_"
    }
}