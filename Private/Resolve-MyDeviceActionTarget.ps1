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
        [string] $AutopilotDeviceId,

        [Parameter()]
        [ValidateSet('Entra', 'Intune', 'Autopilot')]
        [string] $TargetType
    )

    $resolvedEntraDeviceObjectId = $EntraDeviceObjectId
    $resolvedManagedDeviceId = $ManagedDeviceId
    $resolvedAutopilotDeviceId = $AutopilotDeviceId
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

        if (-not $resolvedAutopilotDeviceId -and $InputObject.PSObject.Properties['AutopilotDeviceId']) {
            $resolvedAutopilotDeviceId = $InputObject.AutopilotDeviceId
        }

        if (-not $resolvedAutopilotDeviceId -and $InputObject.PSObject.Properties['WindowsAutopilotDeviceIdentityId']) {
            $resolvedAutopilotDeviceId = $InputObject.WindowsAutopilotDeviceIdentityId
        }

        if (-not $resolvedAutopilotDeviceId -and $TargetType -eq 'Autopilot' -and $InputObject.PSObject.Properties['Id']) {
            $resolvedAutopilotDeviceId = $InputObject.Id
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
        } elseif ($TargetType -eq 'Autopilot' -and $resolvedAutopilotDeviceId) {
            $resolvedDisplayName = $resolvedAutopilotDeviceId
        }
    }

    if ($TargetType -eq 'Entra' -and -not $resolvedEntraDeviceObjectId) {
        throw "Resolve-MyDeviceActionTarget - Unable to resolve Entra device object id."
    }

    if ($TargetType -eq 'Intune' -and -not $resolvedManagedDeviceId) {
        throw "Resolve-MyDeviceActionTarget - Unable to resolve Intune managed device id."
    }

    if ($TargetType -eq 'Autopilot' -and -not $resolvedAutopilotDeviceId) {
        throw "Resolve-MyDeviceActionTarget - Unable to resolve Windows Autopilot device identity id."
    }

    [PSCustomObject] @{
        DisplayName         = $resolvedDisplayName
        EntraDeviceObjectId = $resolvedEntraDeviceObjectId
        ManagedDeviceId     = $resolvedManagedDeviceId
        AutopilotDeviceId   = $resolvedAutopilotDeviceId
        DeviceId            = $resolvedDeviceId
    }
}
