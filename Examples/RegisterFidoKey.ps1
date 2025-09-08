Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes "UserAuthenticationMethod.ReadWrite.All" -NoWelcome

$UPN = 'testyubi@evotec.pl'
$DisplayName = "YubiKey1"

$FIDO2 = New-FidoKey -UPN 'testyubi@evotec.pl' -DisplayName "YubiKey1"
$FIDO2