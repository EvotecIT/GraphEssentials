#Clear-Host
Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes DeviceManagementRBAC.Read.All, Application.ReadWrite.All, AccessReview.Read.All, AdministrativeUnit.Read.All, 'User.Read.All', RoleManagement.Read.Directory, Directory.Read.All, EntitlementManagement.Read.All

$Report = Get-MyRole -OnlyWithMembers -Verbose
$Report | Format-Table *

$ReportUsers = Get-MyRoleUsers -OnlyWithRoles -Verbose
$ReportUsers | Format-Table *

$ReportUsers = Get-MyRoleUsers -OnlyWithRoles -RolePerColumn -Verbose
$ReportUsers | Format-Table *

#Install-Modue Microsoft.Graph.Teams -Force -Verbose
#Install-Module Microsoft.Graph.Intune -Force -Verbose

#Get-DeviceManagement_RoleAssignments
