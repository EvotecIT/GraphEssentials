Clear-Host

Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes 'User.Read.All', 'Directory.Read.All', 'SecurityIdentitiesHealth.Read.All', 'SecurityIdentitiesSensors.Read.All', 'SecurityEvents.Read.All', 'SecurityActions.Read.All' -NoWelcome

#$Data = Get-MyDefenderHealthIssues -Status 'open' -SensorDNSName 'AD0.ad.evotec.xyz' -Verbose
#$Data = Get-MyDefenderHealthIssues -Status 'open' -Verbose
#$Data | Format-Table

#$SecureScore = Get-MyDefenderSecureScore -Verbose
#$SecureScore | Format-Table

#$DataSummary = Get-MyDefenderHealthIssues -Status 'open' -Verbose -Summary
#$DataSummary | Format-Table

#$SecureProfile = Get-MyDefenderSecureScoreProfile
#$SecureProfile | Format-Table

Show-MyDefender -FilePath "$PSScriptRoot\Reports\MyDefender.html" -Online -ShowHTML -Verbose