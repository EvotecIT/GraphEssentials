function Resolve-MyDeviceActionTarget {
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSObject] $InputObject,

        [Parameter()]
        [string] $EntraDeviceObjectId,

        [Parameter()]
        [string] $ManagedDeviceId,

        [Parameter()]
        [ValidateSet('Entra', 'Intune')]
        [string] $TargetType
    )

    $resolvedEntraDeviceObjectId = $EntraDeviceObjectId
    $resolvedManagedDeviceId = $ManagedDeviceId
    $resolvedDisplayName = $null
    $resolvedDeviceId = $null

    if ($InputObject) {
        if ($InputObject.PSObject.Properties['Name']) {
            $resolvedDisplayName = $InputObject.Name
        } elseif ($InputObject.PSObject.Properties['DisplayName']) {
            $resolvedDisplayName = $InputObject.DisplayName
        } elseif ($InputObject.PSObject.Properties['ManagedDeviceName']) {
            $resolvedDisplayName = $InputObject.ManagedDeviceName
        }

        if (-not $resolvedEntraDeviceObjectId -and $InputObject.PSObject.Properties['EntraDeviceObjectId']) {
            $resolvedEntraDeviceObjectId = $InputObject.EntraDeviceObjectId
        }

        if (-not $resolvedManagedDeviceId -and $InputObject.PSObject.Properties['ManagedDeviceId']) {
            $resolvedManagedDeviceId = $InputObject.ManagedDeviceId
        }

        if (-not $resolvedManagedDeviceId -and
            $InputObject.PSObject.Properties['AzureAdDeviceId'] -and
            $InputObject.PSObject.Properties['Id']) {
            $resolvedManagedDeviceId = $InputObject.Id
        }

        if ($InputObject.PSObject.Properties['DeviceId']) {
            $resolvedDeviceId = $InputObject.DeviceId
        } elseif ($InputObject.PSObject.Properties['AzureAdDeviceId']) {
            $resolvedDeviceId = $InputObject.AzureAdDeviceId
        }
    }

    if (-not $resolvedDisplayName) {
        if ($TargetType -eq 'Entra' -and $resolvedEntraDeviceObjectId) {
            $resolvedDisplayName = $resolvedEntraDeviceObjectId
        } elseif ($TargetType -eq 'Intune' -and $resolvedManagedDeviceId) {
            $resolvedDisplayName = $resolvedManagedDeviceId
        }
    }

    if ($TargetType -eq 'Entra' -and -not $resolvedEntraDeviceObjectId) {
        throw "Resolve-MyDeviceActionTarget - Unable to resolve Entra device object id."
    }

    if ($TargetType -eq 'Intune' -and -not $resolvedManagedDeviceId) {
        throw "Resolve-MyDeviceActionTarget - Unable to resolve Intune managed device id."
    }

    [PSCustomObject] @{
        DisplayName         = $resolvedDisplayName
        EntraDeviceObjectId = $resolvedEntraDeviceObjectId
        ManagedDeviceId     = $resolvedManagedDeviceId
        DeviceId            = $resolvedDeviceId
    }
}
