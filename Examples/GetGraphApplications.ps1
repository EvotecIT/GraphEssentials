Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Application.ReadWrite.All

$Applications = Get-MyApp
$ApplicationsPassword = Get-MyAppCredentials
$Applications | Format-Table
$ApplicationsPassword | Format-Table *