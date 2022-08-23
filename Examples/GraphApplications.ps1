Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Application.ReadWrite.All

$Applications = Get-MyApp
$ApplicationsPassword = Get-MyAppCredentials
Show-MyApp -FilePath $PSScriptRoot\Reports\Applications.html -Show