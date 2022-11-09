Import-Module .\GraphEssentials.psd1 -Force

$Modules = @(
    'Microsoft.Graph.Identity.DirectoryManagement'
    'Microsoft.Graph.Authentication'
    'Microsoft.Graph.Users'
    'Microsoft.Graph.DeviceManagement.Enrolment'
    'mIcrosoft.Graph.Applications'
)

Connect-MgGraph -Scopes Application.ReadWrite.All, AccessReview.Read.All, AdministrativeUnit.Read.All, 'User.Read.All', RoleManagement.Read.Directory, Directory.Read.All, EntitlementManagement.Read.All

Invoke-MyGraphEssentials -Type Roles, RolesUsers, RolesUsersPerColumn -FilePath $PSScriptRoot\Reports\RolesUsers.html -Verbose -SplitReports