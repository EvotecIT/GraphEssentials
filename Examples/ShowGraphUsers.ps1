Import-Module .\GraphEssentials.psd1 -Force

$ProgressPreference = 'SilentlyContinue'

Connect-MgGraph -Scopes "Policy.Read.All", "Organization.Read.All", "AuditLog.Read.All", "UserAuthenticationMethod.Read.All", "RoleAssignmentSchedule.Read.Directory", "RoleEligibilitySchedule.Read.Directory", 'User.Read.All' -NoWelcome

Show-MyUserAuthentication -FilePath "$PSScriptRoot\Reports\MyUserAuthentication.html" -Online -ShowHTML -Verbose #-IncludeSecurityQuestionStatus

return

$User = Get-MyUserAuthentication -UserPrincipalName "Przemyslaw.klys@evotec.pl" -Verbose
$User | Format-Table

$Users = Get-MyUserAuthentication
$Users | Format-Table