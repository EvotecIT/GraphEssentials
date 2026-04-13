function Remove-MyDevice {
    <#
    .SYNOPSIS
    Removes a Microsoft Entra device.

    .DESCRIPTION
    Deletes a Microsoft Entra device from the directory.
    The function accepts either a device object returned by GraphEssentials cmdlets
    or an explicit Entra device object id.

    .PARAMETER InputObject
    Device object returned by Get-MyDevice, Get-MyDeviceIntune, or another object
    that exposes EntraDeviceObjectId.

    .PARAMETER EntraDeviceObjectId
    The Microsoft Entra device object id to remove.

    .EXAMPLE
    Get-MyDevice -Type 'AzureAD registered' | Remove-MyDevice -WhatIf

    .EXAMPLE
    Remove-MyDevice -EntraDeviceObjectId '00000000-0000-0000-0000-000000000000'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByObject')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [PSObject] $InputObject,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string] $EntraDeviceObjectId
    )

    process {
        try {
            $resolvedTarget = Resolve-MyDeviceActionTarget -InputObject $InputObject -EntraDeviceObjectId $EntraDeviceObjectId -TargetType 'Entra'
        } catch {
            $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Remove-MyDevice'
            Write-Error -Message $errorInfo.FullMessage
            return
        }

        $output = [ordered] @{
            Action              = 'RemoveEntraDevice'
            DisplayName         = $resolvedTarget.DisplayName
            EntraDeviceObjectId = $resolvedTarget.EntraDeviceObjectId
            ManagedDeviceId     = $resolvedTarget.ManagedDeviceId
            DeviceId            = $resolvedTarget.DeviceId
            Success             = $false
            Message             = $null
        }

        if (-not $PSCmdlet.ShouldProcess($resolvedTarget.DisplayName, 'Remove Microsoft Entra device')) {
            $output.Message = 'Operation skipped by ShouldProcess.'
            [PSCustomObject] $output
            return
        }

        try {
            $removeMgDeviceSplat = @{
                DeviceId    = $resolvedTarget.EntraDeviceObjectId
                ErrorAction = 'Stop'
            }
            Remove-MgDevice @removeMgDeviceSplat | Out-Null

            $output.Success = $true
            $output.Message = 'Device removed successfully.'
        } catch {
            $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Remove-MyDevice'
            $output.Message = $errorInfo.Message
            Write-Error -Message $errorInfo.FullMessage
        }

        [PSCustomObject] $output
    }
}
