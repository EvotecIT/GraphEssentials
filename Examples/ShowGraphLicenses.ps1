Import-Module .\GraphEssentials.psd1 -Force

$AccessToken = Get-MgToken -Domain 'evotec.pl' -ClientID '206245ab-da91-490c-8e69-7a7f3db6df25' -ClientSecret $Env:GraphClientSecret

Connect-MgGraph -AccessToken $AccessToken

Invoke-MyGraphEssentials -Type Users, UsersPerLicense, UsersPerServicePlan, Licenses -FilePath $PSScriptRoot\Reports\GraphEssentials.html -Verbose #-SplitReports