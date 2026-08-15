Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Device.Read.All, DeviceManagementManagedDevices.Read.All, Directory.Read.All, User.Read.All, AuditLog.Read.All, Policy.Read.All, Agreement.Read.All

Get-MyDevice | Format-Table Name, FirstSeen, LastSeen, LastSeenDays, OwnerCount, OwnerDisplayName, TrustType

Get-MyDeviceIntune | Format-Table Name, LastSeen, LastSeenDays, DetailedInventoryLoaded, SerialNumber, Model

Get-MyDeviceIntune -IncludeDetailedInventory | Format-Table Name, DetailedInventoryLoaded, ActivationLockBypassCode, EthernetMacAddress, Iccid, Notes, PhysicalMemoryInBytes, Udid

# Sign-in activity is opt-in and requires AuditLog.Read.All.
Get-MyUser -IncludeSignInActivity | Format-Table DisplayName, UserType, Enabled, LastSignInDateTime, NeverSignedIn, HasLicenses, HasManager

Get-MyGuest -IncludeSignInActivity | Format-Table DisplayName, GuestDomain, Enabled, ExternalUserState, LastSignInDateTime, NeverSignedIn, HasRoles, HasLicenses

Get-MyLicense | Format-Table Name, LicensesUsedPercent, LicensesUsedCount, LicenseCountEnabled, UtilizationBand

Get-MyAppCredentials | Select-Object -First 10 | Format-Table ApplicationName, Type, KeyDisplayName, DaysToExpire, Expired

Get-MyRoleUsers -OnlyWithRoles | Select-Object -First 10 | Format-Table Name, Type, Enabled, DirectCount, EligibleCount, GroupDirectCount, GroupEligibleCount, AllRolesCount

Invoke-MyGraphEssentials -Type Devices, DevicesIntune, Users, UsersPerLicense, UsersPerServicePlan, Guests, Licenses, Apps, AppsCredentials, RolesUsers, RolesUsersPerColumn, Roles, Teams -FilePath "$PWD\Reports\GraphEssentialsReports.html" -Online
