Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Application.ReadWrite.All, AccessReview.Read.All, AdministrativeUnit.Read.All, 'User.Read.All', RoleManagement.Read.Directory, Directory.Read.All, EntitlementManagement.Read.All

#Invoke-MyGraphEssentials -Type DevicesIntune, Roles, RolesUsers, RolesUsersPerColumn #, Apps, AppsCredentials -FilePath $PSScriptRoot\Reports\GraphEssentials.html -Verbose #-SplitReports
#Invoke-MyGraphEssentials -Type RolesUsersPerColumn -FilePath $PSScriptRoot\Reports\GraphEssentials.html -Verbose #-SplitReports
#Invoke-MyGraphEssentials -Type Devices, DevicesIntune, Users -FilePath $PSScriptRoot\Reports\GraphEssentials.html -Verbose #-SplitReports

#Get-MyDevice -Synchronized | Format-Table
Get-MyDeviceIntune -Synchronized | Format-Table