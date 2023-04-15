Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Application.ReadWrite.All, Device.Read.All, DeviceManagementManagedDevices.Read.All, Directory.ReadWrite.All, DeviceManagementConfiguration.Read.All

New-HTML {
    New-HTMLTableOption -DataStore JavaScript -ArrayJoinString ", " -ArrayJoin
    New-HTMLSection -HeaderText 'Devices' -Content {
        New-HTMLTable -DataTable (Get-MyDevice) -ScrollX -Filtering
    }
    New-HTMLSection -HeaderText 'Devices in Intune' -Content {
        New-HTMLTable -DataTable (Get-MyDeviceIntune) -ScrollX -Filtering
    }
} -ShowHTML -FilePath $PSScriptRoot\Reports\Users.html