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
    When specified, returns only synchronized devices (devices with OnPremisesSyncEnabled set to true).

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
        [switch] $Synchronized
    )

    $TrustTypes = @{
        'ServerAD'  = 'Hybrid AzureAD'
        'AzureAD'   = 'AzureAD joined'
        'Workplace' = 'AzureAD registered'
    }

    $Today = Get-Date
    try {
        $Devices = Get-MgDevice -All -ExpandProperty RegisteredOwners -ErrorAction Stop
    } catch {
        Write-Warning -Message "Get-MyDevice - Failed to get devices. Error: $($_.Exception.Message)"
        return
    }
    foreach ($Device in $Devices) {
        if ($Device.ApproximateLastSignInDateTime) {
            $LastSeenDays = $( - $($Device.ApproximateLastSignInDateTime - $Today).Days)
        } else {
            $LastSeenDays = $null
        }
        if ($Device.OnPremisesLastSyncDateTime) {
            $LastSynchronizedDays = $( - $($Device.OnPremisesLastSyncDateTime - $Today).Days)
        } else {
            $LastSynchronizedDays = $null
        }

        if ($Device.TrustType) {
            $TrustType = $TrustTypes[$Device.TrustType]
        } else {
            $TrustType = 'Not available'
        }

        if ($Synchronized) {
            # Only return synchronized devices
            if (-not $Device.OnPremisesSyncEnabled) {
                continue
            }
        }
        if ($Type) {
            # Only return devices of the specified type
            if ($Type -notcontains $TrustType) {
                continue
            }
        }

        [PSCustomObject] @{
            Name                   = $Device.DisplayName
            Id                     = $Device.Id
            Enabled                = $Device.AccountEnabled
            OperatingSystem        = $Device.OperatingSystem
            OperatingSystemVersion = $Device.OperatingSystemVersion
            TrustType              = $TrustType
            ProfileType            = $Device.ProfileType
            FirstSeen              = $Device.AdditionalProperties.registrationDateTime
            LastSeen               = $Device.ApproximateLastSignInDateTime
            LastSeenDays           = $LastSeenDays
            Status                 = $Device.AdditionalProperties.deviceOwnership
            OwnerDisplayName       = $Device.RegisteredOwners.AdditionalProperties.displayName
            OwnerEnabled           = $Device.RegisteredOwners.AdditionalProperties.accountEnabled
            OwnerUserPrincipalName = $Device.RegisteredOwners.AdditionalProperties.userPrincipalName
            IsSynchronized         = if ($Device.OnPremisesSyncEnabled) { $true } else { $false }
            LastSynchronized       = $Device.OnPremisesLastSyncDateTime
            LastSynchronizedDays   = $LastSynchronizedDays
            IsCompliant            = $Device.IsCompliant
            IsManaged              = $Device.IsManaged
            DeviceId               = $Device.DeviceId
            Model                  = $Device.AdditionalProperties.model
            Manufacturer           = $Device.AdditionalProperties.manufacturer
            ManagementType         = $Device.AdditionalProperties.managementType
            EnrollmentType         = $Device.AdditionalProperties.enrollmentType
        }
    }
}