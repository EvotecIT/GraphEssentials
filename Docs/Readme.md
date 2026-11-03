---
Module Name: GraphEssentials
Module Guid: 75ef812f-6d8e-4898-81bb-8029e0560ef3
Download Help Link: {{ Update Download Link }}
Help Version: 0.0.69
Locale: en-US
---
# GraphEssentials Module
## Description
GraphEssentials is a PowerShell module that helps with Office 365 / Azure AD using mostly Graph

## GraphEssentials Cmdlets
### [Disable-MyDevice](Disable-MyDevice.md)
Disables a Microsoft Entra device.

### [Get-MgToken](Get-MgToken.md)
Provides a way to get a token for Microsoft Graph API to be used with Connect-MGGraph

### [Get-MyApp](Get-MyApp.md)
Retrieves Azure AD application (Service Principal) information from Microsoft Graph API.

### [Get-MyAppCertificateRotation](Get-MyAppCertificateRotation.md)
Reads safe renewal status or loads the active certificate for Connect-MgGraph.

### [Get-MyAppCredentials](Get-MyAppCredentials.md)
Retrieves Azure AD application credentials information.

### [Get-MyConditionalAccess](Get-MyConditionalAccess.md)
Gets conditional access policies from Microsoft Graph and categorizes them.

### [Get-MyDefenderDeploymentKey](Get-MyDefenderDeploymentKey.md)
Retrieves Microsoft Defender for Identity deployment access key and package URI.

### [Get-MyDefenderHealthIssues](Get-MyDefenderHealthIssues.md)
Retrieves health issues from Microsoft Graph Security API.

### [Get-MyDefenderSecureScore](Get-MyDefenderSecureScore.md)
Retrieves Microsoft Defender secure score information.

### [Get-MyDefenderSecureScoreProfile](Get-MyDefenderSecureScoreProfile.md)
Retrieves Microsoft Defender secure score control profiles.

### [Get-MyDefenderSensor](Get-MyDefenderSensor.md)
Retrieves Microsoft Defender for Identity sensors information.

### [Get-MyDefenderSummary](Get-MyDefenderSummary.md)
Provides a summary of Microsoft Defender for Identity health issues.

### [Get-MyDevice](Get-MyDevice.md)
Gets device information from Microsoft Graph API.

### [Get-MyDeviceIntune](Get-MyDeviceIntune.md)
Retrieves Intune device information from Microsoft Graph API.

### [Get-MyDirectoryUser](Get-MyDirectoryUser.md)
Retrieves selected directory user data, extensions and optional manager details through the Graph SDK.

### [Get-MyGuest](Get-MyGuest.md)
Retrieves guest and external user accounts from Microsoft Graph API.

### [Get-MyLicense](Get-MyLicense.md)
Get-MyLicense [<CommonParameters>]

### [Get-MyRole](Get-MyRole.md)
Retrieves Azure AD directory roles and their assignments.

### [Get-MyRoleHistory](Get-MyRoleHistory.md)
Retrieves Azure AD/Entra ID Privileged Identity Management (PIM) role assignment history.

### [Get-MyRoleUsers](Get-MyRoleUsers.md)
Retrieves detailed information about users assigned to Azure AD roles.

### [Get-MyTeam](Get-MyTeam.md)
Retrieves Teams information from Microsoft Graph API.

### [Get-MyTenantName](Get-MyTenantName.md)
Get Tenant Name from Tenant ID or Domain Name

### [Get-MyUsageReports](Get-MyUsageReports.md)
Retrieves usage report data from Microsoft Graph API.

### [Get-MyUser](Get-MyUser.md)
Retrieves detailed information about users from Microsoft Graph API.

### [Get-MyUserAuthentication](Get-MyUserAuthentication.md)
Retrieves detailed authentication method information for users from Microsoft Graph API using efficient batching.

### [Invoke-MyAppCertificateRotation](Invoke-MyAppCertificateRotation.md)
Advances opt-in application certificate renewal using the Microsoft Graph PowerShell SDK.

### [Invoke-MyDeviceRetire](Invoke-MyDeviceRetire.md)
Retires an Intune managed device.

### [Invoke-MyGraphEssentials](Invoke-MyGraphEssentials.md)
Generates comprehensive reports for various Microsoft Graph resources.

### [Invoke-MyGraphUsageReports](Invoke-MyGraphUsageReports.md)
Generates comprehensive reports for Microsoft 365 service usage.

### [New-MyApp](New-MyApp.md)
Creates or updates an Azure AD application and adds credentials.

### [New-MyAppCredentials](New-MyAppCredentials.md)
Creates new credentials for an existing Azure AD application.

### [New-MyGuestInvitation](New-MyGuestInvitation.md)
Submits guest invitations through bounded SDK batches with explicit per-input outcomes.

### [Register-FIDO2Key](Register-FIDO2Key.md)
Register-FIDO2Key [-UPN] <string> [[-DisplayName] <string>] [-PassThru] [<CommonParameters>]

### [Register-MyAppCertificateRotation](Register-MyAppCertificateRotation.md)
Enrolls an existing application certificate in an opt-in local renewal profile.

### [Remove-MyAppCredentials](Remove-MyAppCredentials.md)
Removes credentials from an Azure AD application.

### [Remove-MyAutopilotDevice](Remove-MyAutopilotDevice.md)
Removes a Windows Autopilot device identity.

### [Remove-MyDevice](Remove-MyDevice.md)
Removes a Microsoft Entra device.

### [Remove-MyDeviceIntuneRecord](Remove-MyDeviceIntuneRecord.md)
Removes an Intune managed device record.

### [Send-MyApp](Send-MyApp.md)
Creates application credentials and emails them to specified recipients.

### [Show-MyApp](Show-MyApp.md)
Generates an HTML report for Azure AD applications, their credentials, permissions, and activity.

### [Show-MyConditionalAccess](Show-MyConditionalAccess.md)
Generates an HTML report for conditional access policies.

### [Show-MyDefender](Show-MyDefender.md)
Generates an HTML report for Microsoft Defender for Identity components.

### [Show-MyRole](Show-MyRole.md)
Generates a comprehensive HTML report for Azure AD roles, users, and PIM history.

### [Show-MyUserAuthentication](Show-MyUserAuthentication.md)
Generates an HTML report for user authentication methods and related tenant policies.
