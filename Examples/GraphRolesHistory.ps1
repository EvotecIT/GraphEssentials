Import-Module .\GraphEssentials.psd1 -Force

$ProgressPreference = 'SilentlyContinue'

Connect-MgGraph -Scopes @(
    "RoleManagement.Read.Directory", "RoleManagement.Read.All", 'RoleAssignmentSchedule.Read.Directory', "Directory.Read.All", "AuditLog.Read.All"
) -NoWelcome

# Get last 10000 days of PIM history
Get-MyRoleHistory -Verbose -DaysBack 10000 | Format-Table

return

# Get PIM role history for the last 30 days
$RoleHistory = Get-MyRoleHistory -Verbose
$RoleHistory | Format-Table *

# Get PIM role history for Global Administrator role
$GlobalAdminHistory = Get-MyRoleHistory -RoleName "Global Administrator" -Verbose
$GlobalAdminHistory | Format-Table *

# Get PIM role history for a specific user (replace with actual UPN)
$UserHistory = Get-MyRoleHistory -UserPrincipalName "user@domain.com" -Verbose
$UserHistory | Format-Table *

# # Get history for a specific role
Get-MyRoleHistory -RoleId "b0f54661-2d74-4c50-afa3-1ec803f12efe"

# # Get last 90 days including pending requests
Get-MyRoleHistory -DaysBack 90 -IncludeAllStatuses

# # Get history for a specific user
Get-MyRoleHistory -PrincipalId "e6a8f1cf-0874-4323-a12f-2bf51bb6dfdd"

# Search by role name (exact match)
Get-MyRoleHistory -RoleName "Global Administrator"

# Search by role name (wildcard)
Get-MyRoleHistory -RoleName "*Admin*"

# Search by user principal name
Get-MyRoleHistory -UserPrincipalName "john.doe@company.com"

# Search by user display name (wildcard)
Get-MyRoleHistory -UserPrincipalName "*John*"

# Combine filters - get admin role history for last 90 days
Get-MyRoleHistory -RoleName "*Admin*" -DaysBack 90

# Get all eligible assignment removals
Get-MyRoleHistory | Where-Object { $_.Action -like "*Removed Eligible*" }