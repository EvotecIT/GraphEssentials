function Remove-MyDeviceIntuneRecord {
    <#
    .SYNOPSIS
    Removes an Intune managed device record.

    .DESCRIPTION
    Deletes an Intune managed device record using Microsoft Graph.
    The function accepts either a device object returned by Get-MyDeviceIntune
    or an explicit Intune managed device id.

    .PARAMETER InputObject
    Device object returned by Get-MyDeviceIntune or another object
    that exposes ManagedDeviceId.

    .PARAMETER ManagedDeviceId
    The Intune managed device id to remove.

    .EXAMPLE
    Get-MyDeviceIntune -Type 'AzureAD registered' | Remove-MyDeviceIntuneRecord -WhatIf

    .EXAMPLE
    Remove-MyDeviceIntuneRecord -ManagedDeviceId '00000000-0000-0000-0000-000000000000'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByObject')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [PSObject] $InputObject,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string] $ManagedDeviceId
    )

    process {
        try {
            $resolvedTarget = Resolve-MyDeviceActionTarget -InputObject $InputObject -ManagedDeviceId $ManagedDeviceId -TargetType 'Intune'
        } catch {
            $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Remove-MyDeviceIntuneRecord'
            Write-Error -Message $errorInfo.FullMessage
            return
        }

        $output = [ordered] @{
            Action              = 'RemoveIntuneManagedDevice'
            DisplayName         = $resolvedTarget.DisplayName
            EntraDeviceObjectId = $resolvedTarget.EntraDeviceObjectId
            ManagedDeviceId     = $resolvedTarget.ManagedDeviceId
            DeviceId            = $resolvedTarget.DeviceId
            Success             = $false
            Message             = $null
        }

        if (-not $PSCmdlet.ShouldProcess($resolvedTarget.DisplayName, 'Remove Intune managed device record')) {
            $output.Message = 'Operation skipped by ShouldProcess.'
            [PSCustomObject] $output
            return
        }

        try {
            $removeMgDeviceManagementManagedDeviceSplat = @{
                ManagedDeviceId = $resolvedTarget.ManagedDeviceId
                ErrorAction     = 'Stop'
            }
            Remove-MgDeviceManagementManagedDevice @removeMgDeviceManagementManagedDeviceSplat | Out-Null

            $output.Success = $true
            $output.Message = 'Managed device record removed successfully.'
        } catch {
            $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Remove-MyDeviceIntuneRecord'
            $output.Message = $errorInfo.Message
            Write-Error -Message $errorInfo.FullMessage
        }

        [PSCustomObject] $output
    }
}
