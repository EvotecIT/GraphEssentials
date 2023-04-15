function Get-MyDevice {
    [cmdletBinding()]
    param(

    )

    $TrustTypes = @{
        'ServerAD'  = 'Hybrid AzureAD'
        'AzureAD'   = 'AzureAD joined'
        'Workplace' = 'AzureAD registered'
    }

    $Today = Get-Date
    $Devices = Get-MgDevice -All
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
        [PSCustomObject] @{
            Name                   = $Device.DisplayName
            Id                     = $Device.Id
            Enabled                = $Device.AccountEnabled
            DeviceId               = $Device.DeviceId
            OperatingSystem        = $Device.OperatingSystem
            OperatingSystemVersion = $Device.OperatingSystemVersion
            TrustType              = $TrustTypes[$Device.TrustType]
            FirstSeen              = $Device.AdditionalProperties.registrationDateTime
            LastSeen               = $Device.ApproximateLastSignInDateTime
            LastSeenDays           = $LastSeenDays
            IsSynchronized         = if ($Device.OnPremisesSyncEnabled) { $true } else { $false }
            LastSynchronized       = $Device.OnPremisesLastSyncDateTime
            LastSynchronizedDays   = $LastSynchronizedDays
            IsCompliant            = $Device.IsCompliant
            IsManaged              = $Device.IsManaged
        }
    }
}