function Get-MyDefenderDeploymentKey {
    <#
    .SYNOPSIS
    Retrieves Microsoft Defender for Identity deployment access key and package URI.

    .DESCRIPTION
    Gets the deployment access key and package download URL for Microsoft Defender for Identity sensors.
    These are required when deploying new MDI sensors to your environment.

    .EXAMPLE
    Get-MyDefenderDeploymentKey
    Returns the deployment access key and download URL for Microsoft Defender for Identity sensors.

    .NOTES
    This function requires the Microsoft.Graph.Beta.Security module and appropriate permissions.
    Requires SecurityIdentitiesSensors.Read.All permission.
    #>
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