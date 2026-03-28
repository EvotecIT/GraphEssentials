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
    $Properties = @(
        'accountEnabled', 'approximateLastSignInDateTime', 'deviceId', 'deviceOwnership',
        'displayName', 'enrollmentType', 'id', 'isCompliant', 'isManaged', 'managementType',
        'manufacturer', 'model', 'onPremisesLastSyncDateTime', 'onPremisesSyncEnabled',
        'operatingSystem', 'operatingSystemVersion', 'profileType', 'registrationDateTime',
        'trustType'
    )
    try {
        $Script:DevicesDate = Get-Date
        $Script:Devices = Get-MgDevice -All -Property $Properties -ExpandProperty RegisteredOwners -ErrorAction Stop
    } catch {
        Write-Warning -Message "Get-MyDevice - Failed to get devices. Error: $($_.Exception.Message)"
        return
    }
    foreach ($Device in $Script:Devices) {
        if ($Device.ApproximateLastSignInDateTime) {
            $LastSeenDays = [math]::Floor((New-TimeSpan -Start $Device.ApproximateLastSignInDateTime -End $Today).TotalDays)
        } else {
            $LastSeenDays = $null
        }
        if ($Device.OnPremisesLastSyncDateTime) {
            $LastSynchronizedDays = [math]::Floor((New-TimeSpan -Start $Device.OnPremisesLastSyncDateTime -End $Today).TotalDays)
        } else {
            $LastSynchronizedDays = $null
        }

        if ($Device.TrustType) {
            $TrustType = $TrustTypes[$Device.TrustType]
        } else {
            $TrustType = 'Not available'
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
            FirstSeen              = $Device.RegistrationDateTime
            LastSeen               = $Device.ApproximateLastSignInDateTime
            LastSeenDays           = $LastSeenDays
            Status                 = $Device.DeviceOwnership
            OwnerCount             = @($Device.RegisteredOwners).Count
            OwnerDisplayName       = $OwnerDisplayName
            OwnerEnabled           = $OwnerEnabled
            OwnerUserPrincipalName = $OwnerUserPrincipalName
            IsSynchronized         = if ($Device.OnPremisesSyncEnabled) { $true } else { $false }
            LastSynchronized       = $Device.OnPremisesLastSyncDateTime
            LastSynchronizedDays   = $LastSynchronizedDays
            IsCompliant            = $Device.IsCompliant
            IsManaged              = $Device.IsManaged
            DeviceId               = $Device.DeviceId
            Model                  = $Device.Model
            Manufacturer           = $Device.Manufacturer
            ManagementType         = $Device.ManagementType
            EnrollmentType         = $Device.EnrollmentType
        }
    }
}
