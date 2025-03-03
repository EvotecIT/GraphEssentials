Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes 'User.Read.All', Directory.Read.All
Invoke-MyGraphEssentials -Type Roles, RolesUsers, RolesUsersPerColumn -FilePath $PSScriptRoot\Reports\GraphEssentials.html -Verbose #-SplitReports
Invoke-MyGraphEssentials -Type Users -FilePath $PSScriptRoot\Reports\GraphEssentials.html -Verbose #-SplitReports
Invoke-MyGraphEssentials -Type Users, UsersPerLicense, UsersPerServicePlan, Licenses -FilePath $PSScriptRoot\Reports\GraphEssentials.html -Verbose #-SplitReports