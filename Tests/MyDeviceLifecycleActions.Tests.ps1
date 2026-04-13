BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Resolve-MyDeviceActionTarget.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsErrorDetails.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Disable-MyDevice.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Invoke-MyDeviceRetire.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Remove-MyDevice.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Remove-MyDeviceIntuneRecord.ps1')
}

Describe 'GraphEssentials device lifecycle actions' {
    BeforeEach {
        Mock Update-MgDevice {}
        Mock Invoke-MgRetireDeviceManagementManagedDevice {}
        Mock Remove-MgDevice {}
        Mock Remove-MgDeviceManagementManagedDevice {}
    }

    It 'disables an Entra device using the resolved object id' {
        $device = [PSCustomObject] @{
            Name                = 'iPhone-01'
            EntraDeviceObjectId = 'entra-1'
            DeviceId            = 'device-1'
        }

        $result = Disable-MyDevice -InputObject $device -Confirm:$false

        $result.Success | Should -BeTrue
        Assert-MockCalled Update-MgDevice -Times 1 -Exactly -ParameterFilter {
            $DeviceId -eq 'entra-1' -and $BodyParameter.accountEnabled -eq $false
        }
    }

    It 'retires an Intune device using the managed device id' {
        $device = [PSCustomObject] @{
            Name            = 'Android-01'
            ManagedDeviceId = 'managed-1'
        }

        $result = Invoke-MyDeviceRetire -InputObject $device -Confirm:$false

        $result.Success | Should -BeTrue
        Assert-MockCalled Invoke-MgRetireDeviceManagementManagedDevice -Times 1 -Exactly -ParameterFilter {
            $ManagedDeviceId -eq 'managed-1'
        }
    }

    It 'removes an Entra device using the resolved object id' {
        $device = [PSCustomObject] @{
            Name                = 'iPad-01'
            EntraDeviceObjectId = 'entra-2'
        }

        $result = Remove-MyDevice -InputObject $device -Confirm:$false

        $result.Success | Should -BeTrue
        Assert-MockCalled Remove-MgDevice -Times 1 -Exactly -ParameterFilter {
            $DeviceId -eq 'entra-2'
        }
    }

    It 'removes an Intune device record using the managed device id' {
        $device = [PSCustomObject] @{
            Name            = 'Android-02'
            ManagedDeviceId = 'managed-2'
        }

        $result = Remove-MyDeviceIntuneRecord -InputObject $device -Confirm:$false

        $result.Success | Should -BeTrue
        Assert-MockCalled Remove-MgDeviceManagementManagedDevice -Times 1 -Exactly -ParameterFilter {
            $ManagedDeviceId -eq 'managed-2'
        }
    }
}
