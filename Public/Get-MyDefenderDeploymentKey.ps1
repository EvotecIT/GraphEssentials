function Get-MyDefenderDeploymentKey {
    [cmdletbinding()]
    param(

    )
    $AccessKey = Get-MgBetaSecurityIdentitySensorDeploymentAccessKey
    $PackageUri = Get-MgBetaSecurityIdentitySensorDeploymentPackageUri

    [PSCustomObject]@{
        DeploymentAccessKey = $AccessKey.DeploymentAccessKey
        DownloadUrl         = $PackageUri.DownloadUrl
    }
}