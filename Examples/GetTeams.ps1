Import-Module .\GraphEssentials.psd1 -Force

$ClientID = '62981bdd-0677-4d90-aaf7-55e2f375210d'
$TenantID = 'ceb371f6-8745-4876-a040-69f2d10a9d1a'
$ClientSecret = 'ytK8Q~MykAoyJDgLV0slzXfq6LgYtTFeGWmGMbC2'

$Token = Get-MgToken -ClientID $ClientID -ClientSecret $ClientSecret -TenantID $TenantID
Connect-MgGraph -AccessToken $Token

# $Teams = Get-MyTeam
# $Teams | Format-Table

# $Teams = Get-MyTeam -PerOwner
# $Teams | Format-Table

Invoke-MyGraphEssentials -Type Teams -FilePath $PSScriptRoot\Reports\GraphEssentials.html -Verbose -SplitReports