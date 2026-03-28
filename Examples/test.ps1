Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Device.Read.All, DeviceManagementManagedDevices.Read.All, Directory.Read.All, User.Read.All, Policy.Read.All, Agreement.Read.All

Get-MyDevice | Format-Table Name, FirstSeen, LastSeen, LastSeenDays, OwnerCount, OwnerDisplayName, TrustType

Get-MyDeviceIntune | Format-Table Name, LastSeen, LastSeenDays, DetailedInventoryLoaded, SerialNumber, Model

Get-MyDeviceIntune -IncludeDetailedInventory | Format-Table Name, DetailedInventoryLoaded, ActivationLockBypassCode, EthernetMacAddress, Iccid, Notes, PhysicalMemoryInBytes, Udid

Get-MyGuest | Format-Table DisplayName, GuestDomain, Enabled, ExternalUserState, LastSignInDateTime, NeverSignedIn, HasRoles, HasLicenses

Invoke-MyGraphEssentials -Type Devices, DevicesIntune, Guests, Apps -FilePath "$PWD\Reports\DevicesAndGuests.html" -Online
