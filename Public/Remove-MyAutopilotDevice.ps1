function Remove-MyAutopilotDevice {
    <#
    .SYNOPSIS
    Removes a Windows Autopilot device identity.

    .DESCRIPTION
    Deletes a Windows Autopilot device identity using Microsoft Graph.
    The function accepts either a device object returned by Get-MyDevice or
    Get-MyDeviceIntune with Autopilot enrichment, or an explicit Windows
    Autopilot device identity id.

    .PARAMETER InputObject
    Device object that exposes AutopilotDeviceId or
    WindowsAutopilotDeviceIdentityId.

    .PARAMETER AutopilotDeviceId
    The Windows Autopilot device identity id to remove.

    .EXAMPLE
    Get-MyDeviceIntune -IncludeAutopilotInventory |
        Where-Object AutopilotOnboarded |
        Remove-MyAutopilotDevice -WhatIf

    .EXAMPLE
    Remove-MyAutopilotDevice -AutopilotDeviceId '00000000-0000-0000-0000-000000000000'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByObject')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [PSObject] $InputObject,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string] $AutopilotDeviceId
    )

    process {
        try {
            $resolvedTarget = Resolve-MyDeviceActionTarget -InputObject $InputObject -AutopilotDeviceId $AutopilotDeviceId -TargetType 'Autopilot'
        } catch {
            $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Remove-MyAutopilotDevice'
            Write-Error -Message $errorInfo.FullMessage
            return
        }

        $output = [ordered] @{
            Action              = 'RemoveAutopilotDeviceIdentity'
            DisplayName         = $resolvedTarget.DisplayName
            EntraDeviceObjectId = $resolvedTarget.EntraDeviceObjectId
            ManagedDeviceId     = $resolvedTarget.ManagedDeviceId
            AutopilotDeviceId   = $resolvedTarget.AutopilotDeviceId
            DeviceId            = $resolvedTarget.DeviceId
            Success             = $false
            Message             = $null
        }

        if (-not $PSCmdlet.ShouldProcess($resolvedTarget.DisplayName, 'Remove Windows Autopilot device identity')) {
            $output.Message = 'Operation skipped by ShouldProcess.'
            [PSCustomObject] $output
            return
        }

        try {
            $removeMgDeviceManagementWindowsAutopilotDeviceIdentitySplat = @{
                WindowsAutopilotDeviceIdentityId = $resolvedTarget.AutopilotDeviceId
                ErrorAction                      = 'Stop'
            }
            Remove-MgDeviceManagementWindowsAutopilotDeviceIdentity @removeMgDeviceManagementWindowsAutopilotDeviceIdentitySplat | Out-Null

            $output.Success = $true
            $output.Message = 'Windows Autopilot device identity removed successfully.'
        } catch {
            $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Remove-MyAutopilotDevice'
            $output.Message = $errorInfo.Message
            Write-Error -Message $errorInfo.FullMessage
        }

        [PSCustomObject] $output
    }
}
