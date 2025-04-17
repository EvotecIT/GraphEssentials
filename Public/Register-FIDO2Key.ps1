function Register-FIDO2Key {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$UPN,
        [string]$DisplayName = "YubiKey",
        [switch]$PassThru
    )
    $FIDO2Options = Get-PasskeyRegistrationOptions -UserId $UPN -ErrorAction Stop
    $FIDO2 = New-Passkey -Options $FIDO2Options -DisplayName $DisplayName -ErrorAction Stop
    if ($FIDO2) {
        Register-FIDO2KeyInEntraID -UPN $UPN -DisplayName $DisplayName -FIDO2 $FIDO2
        Test-Fido2Registration -UPN $UPN -DisplayName $DisplayName

        if ($PassThru) {
            $FIDO2
        }
    }
}