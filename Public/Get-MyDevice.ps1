function Get-MyDevice {
    <#
    .SYNOPSIS
    Gets device information from Microsoft Graph API.

    .DESCRIPTION
    Retrieves device information from Microsoft Graph API and formats it for easy consumption.
    Allows filtering by device type (Hybrid, AzureAD joined, etc.) and synchronization status.

    .PARAMETER Type
    Filter devices by type. Valid values are 'Hybrid AzureAD', 'AzureAD joined', 'AzureAD registered', and 'Not available'.

    .PARAMETER Synchronized
    Returns only synchronized devices when specified (OnPremisesSyncEnabled is true).

    .PARAMETER IncludeAutopilotInventory
    When specified, enriches devices with Windows Autopilot identity metadata.

    .EXAMPLE
    Get-MyDevice
    Returns all devices from the Microsoft Graph API.

    .EXAMPLE
    Get-MyDevice -Type 'AzureAD joined'
    Returns only AzureAD joined devices.

    .EXAMPLE
    Get-MyDevice -Synchronized
    Returns only synchronized devices.

    .NOTES
    This function requires the Microsoft.Graph.Authentication module and appropriate permissions.
    #>
    [cmdletBinding()]
    param(
        [ValidateSet('Hybrid AzureAD', 'AzureAD joined', 'AzureAD registered', 'Not available')][string[]] $Type,
        [switch] $Synchronized,
        [switch] $IncludeAutopilotInventory
    )

    $TrustTypes = @{
        'ServerAD'  = 'Hybrid AzureAD'
        'AzureAD'   = 'AzureAD joined'
        'Workplace' = 'AzureAD registered'
    }

    $Today = Get-Date
    $Properties = @(
        'accountEnabled', 'approximateLastSignInDateTime', 'deviceId', 'deviceOwnership',
        'displayName', 'enrollmentType', 'id', 'isCompliant', 'isManaged', 'managementType',
        'manufacturer', 'model', 'onPremisesLastSyncDateTime', 'onPremisesSyncEnabled',
        'operatingSystem', 'operatingSystemVersion', 'profileType', 'registrationDateTime',
        'trustType'
    )
    $AutopilotLookup = $null
    if ($IncludeAutopilotInventory) {
        $AutopilotLookup = Get-GraphEssentialsAutopilotLookup
    }

    $DeviceCache = [System.Collections.Generic.List[object]]::new()
    $NormalizedDevices = [System.Collections.Generic.List[object]]::new()
    try {
        Get-MgDevice -All -Property $Properties -ExpandProperty RegisteredOwners -ErrorAction Stop | ForEach-Object {
            $Device = $_
            if ($Device.DeviceId) {
                $DeviceCache.Add([PSCustomObject] @{
                        DeviceId              = $Device.DeviceId
                        Id                    = $Device.Id
                        OnPremisesSyncEnabled = $Device.OnPremisesSyncEnabled
                        TrustType             = $Device.TrustType
                    })
            }

            if ($Device.TrustType) {
                $TrustType = $TrustTypes[$Device.TrustType]
            }
            else {
                $TrustType = 'Not available'
            }

            if ($Synchronized -and -not $Device.OnPremisesSyncEnabled) {
                return
            }
            if ($Type -and $Type -notcontains $TrustType) {
                return
            }

            if ($Device.ApproximateLastSignInDateTime) {
                $LastSeenDays = [math]::Floor((New-TimeSpan -Start $Device.ApproximateLastSignInDateTime -End $Today).TotalDays)
            }
            else {
                $LastSeenDays = $null
            }
            if ($Device.OnPremisesLastSyncDateTime) {
                $LastSynchronizedDays = [math]::Floor((New-TimeSpan -Start $Device.OnPremisesLastSyncDateTime -End $Today).TotalDays)
            }
            else {
                $LastSynchronizedDays = $null
            }

            $OwnerDisplayName = [System.Collections.Generic.List[string]]::new()
            $OwnerEnabled = [System.Collections.Generic.List[string]]::new()
            $OwnerUserPrincipalName = [System.Collections.Generic.List[string]]::new()
            foreach ($Owner in $Device.RegisteredOwners) {
                if ($Owner.AdditionalProperties.displayName) {
                    $OwnerDisplayName.Add($Owner.AdditionalProperties.displayName)
                }
                if ($null -ne $Owner.AdditionalProperties.accountEnabled) {
                    $OwnerEnabled.Add([string] $Owner.AdditionalProperties.accountEnabled)
                }
                if ($Owner.AdditionalProperties.userPrincipalName) {
                    $OwnerUserPrincipalName.Add($Owner.AdditionalProperties.userPrincipalName)
                }
            }

            $AutopilotDevice = Find-GraphEssentialsAutopilotDevice -Lookup $AutopilotLookup -AzureAdDeviceId $Device.DeviceId
            $AutopilotLastContacted = if ($AutopilotDevice) { Get-GraphEssentialsObjectProperty -InputObject $AutopilotDevice -Name @('LastContactedDateTime', 'lastContactedDateTime') } else { $null }
            $AutopilotLastContactedDays = if ($AutopilotLastContacted) { [math]::Floor((New-TimeSpan -Start $AutopilotLastContacted -End $Today).TotalDays) } else { $null }

            $NormalizedDevices.Add([PSCustomObject] @{
                    Name                       = $Device.DisplayName
                    Id                         = $Device.Id
                    EntraDeviceObjectId        = $Device.Id
                    Enabled                    = $Device.AccountEnabled
                    OperatingSystem            = $Device.OperatingSystem
                    OperatingSystemVersion     = $Device.OperatingSystemVersion
                    TrustType                  = $TrustType
                    ProfileType                = $Device.ProfileType
                    FirstSeen                  = $Device.RegistrationDateTime
                    LastSeen                   = $Device.ApproximateLastSignInDateTime
                    LastSeenDays               = $LastSeenDays
                    Status                     = $Device.DeviceOwnership
                    OwnerCount                 = @($Device.RegisteredOwners).Count
                    OwnerDisplayName           = $OwnerDisplayName
                    OwnerEnabled               = $OwnerEnabled
                    OwnerUserPrincipalName     = $OwnerUserPrincipalName
                    IsSynchronized             = if ($Device.OnPremisesSyncEnabled) { $true } else { $false }
                    LastSynchronized           = $Device.OnPremisesLastSyncDateTime
                    LastSynchronizedDays       = $LastSynchronizedDays
                    IsCompliant                = $Device.IsCompliant
                    IsManaged                  = $Device.IsManaged
                    DeviceId                   = $Device.DeviceId
                    Model                      = $Device.Model
                    Manufacturer               = $Device.Manufacturer
                    ManagementType             = $Device.ManagementType
                    EnrollmentType             = $Device.EnrollmentType
                    AutopilotInventoryLoaded   = if ($IncludeAutopilotInventory) { [bool] $AutopilotLookup.InventoryLoaded } else { $false }
                    AutopilotOnboarded         = if ($IncludeAutopilotInventory -and $AutopilotLookup.InventoryLoaded) { [bool] $AutopilotDevice } else { $null }
                    AutopilotDeviceId          = if ($AutopilotDevice) { Get-GraphEssentialsObjectProperty -InputObject $AutopilotDevice -Name @('Id', 'id') } else { $null }
                    AutopilotManagedDeviceId   = if ($AutopilotDevice) { Get-GraphEssentialsObjectProperty -InputObject $AutopilotDevice -Name @('ManagedDeviceId', 'managedDeviceId') } else { $null }
                    AutopilotAzureAdDeviceId   = if ($AutopilotDevice) { Get-GraphEssentialsObjectProperty -InputObject $AutopilotDevice -Name @('AzureAdDeviceId', 'azureAdDeviceId', 'AzureActiveDirectoryDeviceId', 'azureActiveDirectoryDeviceId') } else { $null }
                    AutopilotResourceName      = if ($AutopilotDevice) { Get-GraphEssentialsObjectProperty -InputObject $AutopilotDevice -Name @('ResourceName', 'resourceName', 'DisplayName', 'displayName') } else { $null }
                    AutopilotGroupTag          = if ($AutopilotDevice) { Get-GraphEssentialsObjectProperty -InputObject $AutopilotDevice -Name @('GroupTag', 'groupTag') } else { $null }
                    AutopilotSerialNumber      = if ($AutopilotDevice) { Get-GraphEssentialsObjectProperty -InputObject $AutopilotDevice -Name @('SerialNumber', 'serialNumber') } else { $null }
                    AutopilotEnrollmentState   = if ($AutopilotDevice) { Get-GraphEssentialsObjectProperty -InputObject $AutopilotDevice -Name @('EnrollmentState', 'enrollmentState') } else { $null }
                    AutopilotLastContacted     = $AutopilotLastContacted
                    AutopilotLastContactedDays = $AutopilotLastContactedDays
                    AutopilotUserPrincipalName = if ($AutopilotDevice) { Get-GraphEssentialsObjectProperty -InputObject $AutopilotDevice -Name @('UserPrincipalName', 'userPrincipalName') } else { $null }
                })
        }
    }
    catch {
        $Script:Devices = $null
        $Script:DevicesDate = $null
        Write-Warning -Message "Get-MyDevice - Failed to get devices. Error: $($_.Exception.Message)"
        return
    }

    $Script:Devices = $DeviceCache
    $Script:DevicesDate = Get-Date
    $NormalizedDevices
}
