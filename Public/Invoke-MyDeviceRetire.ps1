function Invoke-MyDeviceRetire {
    <#
    .SYNOPSIS
    Retires an Intune managed device.

    .DESCRIPTION
    Retires an Intune managed device using Microsoft Graph.
    The function accepts either a device object returned by Get-MyDeviceIntune
    or an explicit Intune managed device id.

    .PARAMETER InputObject
    Device object returned by Get-MyDeviceIntune or another object
    that exposes ManagedDeviceId.

    .PARAMETER ManagedDeviceId
    The Intune managed device id to retire.

    .EXAMPLE
    Get-MyDeviceIntune -Type 'AzureAD registered' | Invoke-MyDeviceRetire -WhatIf

    .EXAMPLE
    Invoke-MyDeviceRetire -ManagedDeviceId '00000000-0000-0000-0000-000000000000'
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
            $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Invoke-MyDeviceRetire'
            Write-Error -Message $errorInfo.FullMessage
            return
        }

        $output = [ordered] @{
            Action              = 'RetireIntuneDevice'
            DisplayName         = $resolvedTarget.DisplayName
            EntraDeviceObjectId = $resolvedTarget.EntraDeviceObjectId
            ManagedDeviceId     = $resolvedTarget.ManagedDeviceId
            DeviceId            = $resolvedTarget.DeviceId
            Success             = $false
            Message             = $null
        }

        if (-not $PSCmdlet.ShouldProcess($resolvedTarget.DisplayName, 'Retire Intune managed device')) {
            $output.Message = 'Operation skipped by ShouldProcess.'
            [PSCustomObject] $output
            return
        }

        try {
            $invokeMgRetireDeviceManagementManagedDeviceSplat = @{
                ManagedDeviceId = $resolvedTarget.ManagedDeviceId
                ErrorAction     = 'Stop'
            }
            Invoke-MgRetireDeviceManagementManagedDevice @invokeMgRetireDeviceManagementManagedDeviceSplat | Out-Null

            $output.Success = $true
            $output.Message = 'Managed device retired successfully.'
        } catch {
            $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Invoke-MyDeviceRetire'
            $output.Message = $errorInfo.Message
            Write-Error -Message $errorInfo.FullMessage
        }

        [PSCustomObject] $output
    }
}
