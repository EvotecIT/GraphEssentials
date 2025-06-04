Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes @(
    "RoleManagement.Read.Directory", "RoleManagement.Read.All", 'RoleAssignmentSchedule.Read.Directory', "Directory.Read.All", "AuditLog.Read.All"
    "RoleAssignmentSchedule.ReadWrite.Directory", "RoleManagement.ReadWrite.Directory", "RoleAssignmentSchedule.Remove.Directory"
) -NoWelcome

# Generate comprehensive HTML report combining all role functions
Show-MyRole -FilePath "$PSScriptRoot\Reports\RoleManagementReport.html" -Online -DaysBack 90 -Verbose -Show