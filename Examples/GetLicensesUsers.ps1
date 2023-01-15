Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Application.ReadWrite.All, AccessReview.Read.All, AdministrativeUnit.Read.All, 'User.Read.All', RoleManagement.Read.Directory, Directory.Read.All, EntitlementManagement.Read.All

Get-MyUser | Format-Table
Get-MyUser -PerServicePlan | Format-Table
Get-MyUser -PerLicense | Format-Table

# Alternative to Invoke-ADessentials - doing reports by hand
New-HTML {
    New-HTMLTableOption -DataStore JavaScript -ArrayJoinString ", " -ArrayJoin
    New-HTMLSection -HeaderText 'Users' -Content {
        New-HTMLTable -DataTable (Get-MyUser) -ScrollX -Filtering
    }
    New-HTMLSection -HeaderText 'Users per License' -Content {
        New-HTMLTable -DataTable (Get-MyUser -PerLicense) -ScrollX -Filtering
    }
    New-HTMLSection -HeaderText 'Users per Service Plan' -Content {
        New-HTMLTable -DataTable (Get-MyUser -PerServicePlan) -ScrollX -Filtering
    }
} -ShowHTML -FilePath $PSScriptRoot\Reports\Users.html