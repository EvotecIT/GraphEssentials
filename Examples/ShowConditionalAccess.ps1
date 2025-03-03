Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes 'Policy.Read.All', 'Agreement.Read.All', Application.ReadWrite.All, AccessReview.Read.All, AdministrativeUnit.Read.All, 'User.Read.All', RoleManagement.Read.Directory, Directory.Read.All, EntitlementManagement.Read.All

# $ConditionalAccess = Get-MyConditionalAccess -Verbose
# $ConditionalAccess | Format-Table

# $ConditionalAccessStatistics = Get-MyConditionalAccess -Verbose -IncludeStatistics
# $ConditionalAccessStatistics | Format-Table

Show-MyConditionalAccess -Verbose -FilePath $PSScriptRoot\Reports\ConditionalAccess.html -Online -ShowHTML