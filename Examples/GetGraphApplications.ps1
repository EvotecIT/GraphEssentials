Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Application.ReadWrite.All

$Applications = Get-MyApp
$Applications | Format-Table

$ApplicationsPassword = Get-MyAppCredentials
$ApplicationsPassword | Format-Table *

$ApplicationsPasswordExpired = Get-MyAppCredentials -Expired -ApplicationName 'TeamsAppDelegation'
$ApplicationsPasswordExpired | Format-Table *

$ApplicationsPasswordExpired = Get-MyAppCredentials -ApplicationName 'TeamsAppDelegation' -LessThanDaysToExpire 15
$ApplicationsPasswordExpired | Format-Table *