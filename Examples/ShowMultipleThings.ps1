Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Device.Read.All, DeviceManagementManagedDevices.Read.All, Directory.Read.All, User.Read.All, AuditLog.Read.All, Policy.Read.All, Agreement.Read.All

Get-MyDevice | Format-Table Name, FirstSeen, LastSeen, LastSeenDays, OwnerCount, OwnerDisplayName, TrustType

Get-MyDeviceIntune | Format-Table Name, LastSeen, LastSeenDays, DetailedInventoryLoaded, SerialNumber, Model

Get-MyDeviceIntune -IncludeDetailedInventory | Format-Table Name, DetailedInventoryLoaded, ActivationLockBypassCode, EthernetMacAddress, Iccid, Notes, PhysicalMemoryInBytes, Udid

Get-MyUser | Format-Table DisplayName, UserType, Enabled, LastSignInDateTime, NeverSignedIn, HasLicenses, HasManager

Get-MyGuest | Format-Table DisplayName, GuestDomain, Enabled, ExternalUserState, LastSignInDateTime, NeverSignedIn, HasRoles, HasLicenses

Get-MyLicense | Format-Table Name, LicensesUsedPercent, LicensesUsedCount, LicenseCountEnabled, UtilizationBand

Invoke-MyGraphEssentials -Type Devices, DevicesIntune, Users, UsersPerLicense, Guests, Licenses, Apps -FilePath "$PWD\Reports\DevicesAndGuests.html" -Online
