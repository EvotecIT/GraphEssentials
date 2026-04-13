function Disable-MyDevice {
    <#
    .SYNOPSIS
    Disables a Microsoft Entra device.

    .DESCRIPTION
    Disables a Microsoft Entra device by setting AccountEnabled to false.
    The function accepts either a device object returned by GraphEssentials cmdlets
    or an explicit Entra device object id.

    .PARAMETER InputObject
    Device object returned by Get-MyDevice, Get-MyDeviceIntune, or another object
    that exposes EntraDeviceObjectId.

    .PARAMETER EntraDeviceObjectId
    The Microsoft Entra device object id to disable.

    .EXAMPLE
    Get-MyDevice -Type 'AzureAD registered' | Disable-MyDevice -WhatIf

    .EXAMPLE
    Disable-MyDevice -EntraDeviceObjectId '00000000-0000-0000-0000-000000000000'
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
            $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Disable-MyDevice'
            Write-Error -Message $errorInfo.FullMessage
            return
        }

        $output = [ordered] @{
            Action              = 'DisableEntraDevice'
            DisplayName         = $resolvedTarget.DisplayName
            EntraDeviceObjectId = $resolvedTarget.EntraDeviceObjectId
            ManagedDeviceId     = $resolvedTarget.ManagedDeviceId
            DeviceId            = $resolvedTarget.DeviceId
            Success             = $false
            Message             = $null
        }

        if (-not $PSCmdlet.ShouldProcess($resolvedTarget.DisplayName, 'Disable Microsoft Entra device')) {
            $output.Message = 'Operation skipped by ShouldProcess.'
            [PSCustomObject] $output
            return
        }

        try {
            $updateMgDeviceSplat = @{
                DeviceId      = $resolvedTarget.EntraDeviceObjectId
                BodyParameter = @{
                    accountEnabled = $false
                }
                ErrorAction   = 'Stop'
            }
            Update-MgDevice @updateMgDeviceSplat | Out-Null

            $output.Success = $true
            $output.Message = 'Device disabled successfully.'
        } catch {
            $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Disable-MyDevice'
            $output.Message = $errorInfo.Message
            Write-Error -Message $errorInfo.FullMessage
        }

        [PSCustomObject] $output
    }
}
