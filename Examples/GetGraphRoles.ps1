Import-Module .\GraphEssentials.psd1 -Force

# $Modules = @(
#     'Microsoft.Graph.Identity.DirectoryManagement'
#     'Microsoft.Graph.Authentication'
#     'Microsoft.Graph.Users'
#     'Microsoft.Graph.DeviceManagement.Enrolment'
#     'Microsoft.Graph.Applications'
# )

Connect-MgGraph -Scopes Application.ReadWrite.All, AccessReview.Read.All, AdministrativeUnit.Read.All, 'User.Read.All', RoleManagement.Read.Directory, Directory.Read.All, EntitlementManagement.Read.All

$Report = Get-MyRole -OnlyWithMembers -Verbose
$Report | Format-Table

$ReportUsers = Get-MyRoleUsers -OnlyWithRoles -Verbose
$ReportUsers | Format-Table

$ReportUsers = Get-MyRoleUsers -OnlyWithRoles -RolePerColumn -Verbose
$ReportUsers | Format-Table *