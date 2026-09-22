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

    .PARAMETER PropertySet
    Full retains the complete device information. Lifecycle omits registered owners.
    Computer returns only the dates, identifiers, and owner fields needed for computer
    inventory correlation. Computer requests retry individual Graph pages, so a failed
    page does not restart a large inventory. Owner continuations are read when present;
    a possibly truncated owner expansion makes the inventory fail.

    .PARAMETER ReportProgress
    With the Computer property set, writes page and record counts to the information
    stream for transcripts while Graph inventory is being fetched.

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
        [switch] $IncludeAutopilotInventory,
        [ValidateSet('Full', 'Lifecycle', 'Computer')]
        [string] $PropertySet = 'Full',
        [switch] $ReportProgress
    )

    if ($PropertySet -eq 'Computer' -and $IncludeAutopilotInventory) {
        throw 'Computer property set does not include Autopilot information.'
    }

    $TrustTypes = @{
        'ServerAD'  = 'Hybrid AzureAD'
        'AzureAD'   = 'AzureAD joined'
        'Workplace' = 'AzureAD registered'
    }

    $Today = Get-Date
    $FullProperties = @(
        'accountEnabled', 'approximateLastSignInDateTime', 'deviceId', 'deviceOwnership',
        'displayName', 'enrollmentType', 'id', 'isCompliant', 'isManaged', 'managementType',
        'manufacturer', 'model', 'onPremisesLastSyncDateTime', 'onPremisesSyncEnabled',
        'operatingSystem', 'operatingSystemVersion', 'profileType', 'registrationDateTime',
        'trustType'
    )
    $ComputerProperties = @(
        'approximateLastSignInDateTime', 'deviceId', 'displayName', 'id',
        'onPremisesLastSyncDateTime', 'onPremisesSyncEnabled', 'trustType'
    )
    $AutopilotLookup = $null
    if ($IncludeAutopilotInventory) {
        $AutopilotLookup = Get-GraphEssentialsAutopilotLookup
    }

    $DeviceCache = [System.Collections.Generic.List[object]]::new()
    $NormalizedDevices = [System.Collections.Generic.List[object]]::new()
    try {
        $getDevices = if ($PropertySet -eq 'Computer') {
            $query = '/v1.0/devices?$select=' + ($ComputerProperties -join ',') + '&$top=200'
            if ($Synchronized) {
                $query += '&$filter=onPremisesSyncEnabled%20eq%20true'
            }
            $query += '&$expand=registeredOwners($select=id,displayName,userPrincipalName,accountEnabled)'
            { Get-GraphEssentialsPagedInventory -Uri $query -ReportProgress:$ReportProgress }
        } elseif ($PropertySet -eq 'Lifecycle') {
            { Get-MgDevice -All -Property $FullProperties -ErrorAction Stop }
        } else {
            { Get-MgDevice -All -Property $FullProperties -ExpandProperty RegisteredOwners -ErrorAction Stop }
        }
        & $getDevices | ForEach-Object {
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
                $lastSeenStart = if ($Device.ApproximateLastSignInDateTime -is [DateTimeOffset]) { $Device.ApproximateLastSignInDateTime.UtcDateTime } else { $Device.ApproximateLastSignInDateTime }
                $LastSeenDays = [math]::Floor((New-TimeSpan -Start $lastSeenStart -End $Today).TotalDays)
            }
            else {
                $LastSeenDays = $null
            }
            if ($Device.OnPremisesLastSyncDateTime) {
                $lastSyncStart = if ($Device.OnPremisesLastSyncDateTime -is [DateTimeOffset]) { $Device.OnPremisesLastSyncDateTime.UtcDateTime } else { $Device.OnPremisesLastSyncDateTime }
                $LastSynchronizedDays = [math]::Floor((New-TimeSpan -Start $lastSyncStart -End $Today).TotalDays)
            }
            else {
                $LastSynchronizedDays = $null
            }

            $OwnerDisplayName = [System.Collections.Generic.List[string]]::new()
            $OwnerEnabled = [System.Collections.Generic.List[string]]::new()
            $OwnerUserPrincipalName = [System.Collections.Generic.List[string]]::new()
            $OwnerCount = 0
            if ($PropertySet -eq 'Computer' -and
                (($null -eq $Device.PSObject.Properties['registeredOwners'] -and
                    -not ($Device -is [System.Collections.IDictionary] -and $Device.Contains('registeredOwners'))) -or
                    $null -eq $Device.RegisteredOwners)) {
                throw "Graph omitted registeredOwners for device '$($Device.Id)'."
            }
            $RegisteredOwners = $Device.RegisteredOwners
            if ($PropertySet -eq 'Computer') {
                $ownerNextLink = $Device.'registeredOwners@odata.nextLink'
                if ($ownerNextLink) {
                    $RegisteredOwners = [System.Collections.Generic.List[object]]::new()
                    foreach ($Owner in $Device.RegisteredOwners) {
                        if ($null -ne $Owner) {
                            $RegisteredOwners.Add($Owner)
                        }
                    }
                    foreach ($Owner in (Get-GraphEssentialsPagedInventory -Uri $ownerNextLink)) {
                        $RegisteredOwners.Add($Owner)
                    }
                } elseif ($Device.RegisteredOwners.Count -ge 20) {
                    throw "Graph may have truncated registeredOwners for device '$($Device.Id)'."
                }
            }
            foreach ($Owner in $RegisteredOwners) {
                if ($null -eq $Owner) {
                    continue
                }
                $OwnerCount++
                $ownerProperties = if ($Owner.AdditionalProperties) { $Owner.AdditionalProperties } else { $Owner }
                if ($PropertySet -eq 'Computer') {
                    $hasOwnerStatus = $null -ne $ownerProperties.PSObject.Properties['accountEnabled'] -or
                        ($ownerProperties -is [System.Collections.IDictionary] -and $ownerProperties.Contains('accountEnabled'))
                    if (-not $hasOwnerStatus -or $ownerProperties.accountEnabled -isnot [bool]) {
                        throw "Graph omitted a Boolean accountEnabled for a registered owner of device '$($Device.Id)'."
                    }
                }
                if ($ownerProperties.displayName) {
                    $OwnerDisplayName.Add($ownerProperties.displayName)
                }
                if ($null -ne $ownerProperties.accountEnabled) {
                    $OwnerEnabled.Add([string] $ownerProperties.accountEnabled)
                }
                if ($ownerProperties.userPrincipalName) {
                    $OwnerUserPrincipalName.Add($ownerProperties.userPrincipalName)
                }
            }

            if ($PropertySet -eq 'Computer') {
                $lastSeen = if ($Device.ApproximateLastSignInDateTime) { [DateTimeOffset] $Device.ApproximateLastSignInDateTime } else { $null }
                $lastSynchronized = if ($Device.OnPremisesLastSyncDateTime) { [DateTimeOffset] $Device.OnPremisesLastSyncDateTime } else { $null }
                $NormalizedDevices.Add([PSCustomObject] @{
                    Name                   = $Device.DisplayName
                    Id                     = $Device.Id
                    EntraDeviceObjectId    = $Device.Id
                    DeviceId               = $Device.DeviceId
                    TrustType              = $TrustType
                    IsSynchronized         = [bool] $Device.OnPremisesSyncEnabled
                    LastSeen               = $lastSeen
                    LastSeenDays           = $LastSeenDays
                    LastSynchronized       = $lastSynchronized
                    LastSynchronizedDays   = $LastSynchronizedDays
                    OwnerDisplayName       = $OwnerDisplayName
                    OwnerEnabled           = $OwnerEnabled
                    OwnerUserPrincipalName = $OwnerUserPrincipalName
                })
                return
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
                    OwnerCount                 = $OwnerCount
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
                    AutopilotMatchAmbiguous    = [bool] ($AutopilotDevice -and $AutopilotDevice.MatchAmbiguous)
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
        $Script:DevicesScope = $null
        Write-Warning -Message "Get-MyDevice - Failed to get devices. Error: $($_.Exception.Message)"
        return
    }

    $Script:Devices = $DeviceCache
    $Script:DevicesDate = Get-Date
    $Script:DevicesScope = if ($Synchronized -and $PropertySet -eq 'Computer') { 'Synchronized' } else { 'All' }
    $NormalizedDevices
}
