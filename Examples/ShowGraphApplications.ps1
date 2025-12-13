Clear-Host

Import-Module .\GraphEssentials.psd1 -Force

$connectMgGraphSplat = @{
    Scopes    = @(
        "Application.Read.All", "Policy.Read.PermissionGrant", "Directory.Read.All", "AuditLog.Read.All"
    )
    NoWelcome = $true
}

Connect-MgGraph @connectMgGraphSplat

Show-MyApp -FilePath $PSScriptRoot\Reports\Applications.html -Show -Verbose -ApplicationType AppRegistrations
return
$App = Get-MyApp -ApplicationName 'Microsoft Graph PowerShell' #-Verbose
$App | Format-List


# $App = Get-MyApp -ApplicationName 'Microsoft Graph PowerShell' -IncludeDetailedSignInLogs
# $App | Format-List