Import-Module .\GraphEssentials.psd1 -Force

Install-Module GraphEssentials
Connect-MgGraph -Scopes Application.ReadWrite.All, AccessReview.Read.All, AdministrativeUnit.Read.All, 'User.Read.All', RoleManagement.Read.Directory, Directory.Read.All, EntitlementManagement.Read.All

Invoke-MyGraphEssentials -Type Roles, RolesUsers, RolesUsersPerColumn, Apps, AppsCredentials -FilePath $PSScriptRoot\Reports\GraphEssentials.html -Verbose -SplitReports
#Invoke-MyGraphEssentials -Type RolesUsersPerColumn -FilePath $PSScriptRoot\Reports\GraphEssentials.html -Verbose #-SplitReports