Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Application.ReadWrite.All

$Applications = Get-MyApp -ApplicationName 'Application to manage WDATP TVM Network scan agent - 0c16c592b725f196aaf7bedfe6bad3ec4697b28e'
$Applications | Format-Table

$ApplicationsPassword = Get-MyAppCredentials
$ApplicationsPassword | Format-Table *

$ApplicationsPasswordExpired = Get-MyAppCredentials -Expired -ApplicationName 'TeamsAppDelegation'
$ApplicationsPasswordExpired | Format-Table *

$ApplicationsPasswordExpired = Get-MyAppCredentials -ApplicationName 'TeamsAppDelegation' -LessThanDaysToExpire 15
$ApplicationsPasswordExpired | Format-Table *