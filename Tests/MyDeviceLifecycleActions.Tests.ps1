BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Resolve-MyDeviceActionTarget.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsErrorDetails.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Disable-MyDevice.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Invoke-MyDeviceRetire.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Remove-MyAutopilotDevice.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Remove-MyDevice.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Remove-MyDeviceIntuneRecord.ps1')

    function Update-MgDevice {}
    function Invoke-MgRetireDeviceManagementManagedDevice {}
    function Remove-MgDeviceManagementWindowsAutopilotDeviceIdentity {}
    function Remove-MgDevice {}
    function Remove-MgDeviceManagementManagedDevice {}
}

Describe 'GraphEssentials device lifecycle actions' {
    BeforeEach {
        $script:UpdateMgDeviceCall = $null
        $script:RetireManagedDeviceCall = $null
        $script:RemoveAutopilotDeviceCall = $null
        $script:RemoveMgDeviceCall = $null
        $script:RemoveManagedDeviceCall = $null

        function Update-MgDevice {
            param(
                $DeviceId,
                $BodyParameter,
                $ErrorAction
            )

            $script:UpdateMgDeviceCall = [PSCustomObject] @{
                DeviceId      = $DeviceId
                BodyParameter = $BodyParameter
                ErrorAction   = $ErrorAction
            }
        }

        function Invoke-MgRetireDeviceManagementManagedDevice {
            param(
                $ManagedDeviceId,
                $ErrorAction
            )

            $script:RetireManagedDeviceCall = [PSCustomObject] @{
                ManagedDeviceId = $ManagedDeviceId
                ErrorAction     = $ErrorAction
            }
        }

        function Remove-MgDevice {
            param(
                $DeviceId,
                $ErrorAction
            )

            $script:RemoveMgDeviceCall = [PSCustomObject] @{
                DeviceId    = $DeviceId
                ErrorAction = $ErrorAction
            }
        }

        function Remove-MgDeviceManagementWindowsAutopilotDeviceIdentity {
            param(
                $WindowsAutopilotDeviceIdentityId,
                $ErrorAction
            )

            $script:RemoveAutopilotDeviceCall = [PSCustomObject] @{
                WindowsAutopilotDeviceIdentityId = $WindowsAutopilotDeviceIdentityId
                ErrorAction                      = $ErrorAction
            }
        }

        function Remove-MgDeviceManagementManagedDevice {
            param(
                $ManagedDeviceId,
                $ErrorAction
            )

            $script:RemoveManagedDeviceCall = [PSCustomObject] @{
                ManagedDeviceId = $ManagedDeviceId
                ErrorAction     = $ErrorAction
            }
        }
    }

    It 'disables an Entra device using the resolved object id' {
        $device = [PSCustomObject] @{
            Name                = 'iPhone-01'
            EntraDeviceObjectId = 'entra-1'
            DeviceId            = 'device-1'
        }

        $result = Disable-MyDevice -InputObject $device -Confirm:$false

        $result.Success | Should -BeTrue
        $script:UpdateMgDeviceCall.DeviceId | Should -Be 'entra-1'
        $script:UpdateMgDeviceCall.BodyParameter.accountEnabled | Should -BeFalse
    }

    It 'retires an Intune device using the managed device id' {
        $device = [PSCustomObject] @{
            Name            = 'Android-01'
            ManagedDeviceId = 'managed-1'
        }

        $result = Invoke-MyDeviceRetire -InputObject $device -Confirm:$false

        $result.Success | Should -BeTrue
        $script:RetireManagedDeviceCall.ManagedDeviceId | Should -Be 'managed-1'
    }

    It 'removes an Autopilot device identity using the resolved Autopilot id' {
        $device = [PSCustomObject] @{
            Name              = 'Windows-Autopilot-01'
            AutopilotDeviceId = 'autopilot-1'
            ManagedDeviceId   = 'managed-1'
        }

        $result = Remove-MyAutopilotDevice -InputObject $device -Confirm:$false

        $result.Success | Should -BeTrue
        $script:RemoveAutopilotDeviceCall.WindowsAutopilotDeviceIdentityId | Should -Be 'autopilot-1'
    }

    It 'removes an Entra device using the resolved object id' {
        $device = [PSCustomObject] @{
            Name                = 'iPad-01'
            EntraDeviceObjectId = 'entra-2'
        }

        $result = Remove-MyDevice -InputObject $device -Confirm:$false

        $result.Success | Should -BeTrue
        $script:RemoveMgDeviceCall.DeviceId | Should -Be 'entra-2'
    }

    It 'removes an Intune device record using the managed device id' {
        $device = [PSCustomObject] @{
            Name            = 'Android-02'
            ManagedDeviceId = 'managed-2'
        }

        $result = Remove-MyDeviceIntuneRecord -InputObject $device -Confirm:$false

        $result.Success | Should -BeTrue
        $script:RemoveManagedDeviceCall.ManagedDeviceId | Should -Be 'managed-2'
    }
}
