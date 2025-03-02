function Get-MyDefenderSensor {
    <#
    .SYNOPSIS
    Retrieves Microsoft Defender for Identity sensors information.

    .DESCRIPTION
    Gets detailed information about Microsoft Defender for Identity sensors from the Microsoft Graph Security API.
    Returns sensor properties including display name, domain name, deployment status, health status, and version.

    .EXAMPLE
    Get-MyDefenderSensor
    Returns all Microsoft Defender for Identity sensors.

    .NOTES
    This function requires the Microsoft.Graph.Beta.Security module and appropriate permissions.
    Requires SecurityIdentitiesSensors.Read.All permission.
    #>
    [cmdletbinding()]
    param(

    )
    Write-Verbose -Message 'Get-MyDefenderSensor - Getting all Sensors'
    $Sensors = Get-MgBetaSecurityIdentitySensor -All
    foreach ($Sensor in $Sensors) {
        [PSCustomObject] @{
            DisplayName           = $Sensor.displayName
            DomainName            = $Sensor.domainName
            DeploymentStatus      = $Sensor.deploymentStatus
            HealthStatus          = $Sensor.healthStatus
            OpenHealthIssuesCount = $Sensor.openHealthIssuesCount
            SensorType            = $Sensor.sensorType
            Version               = $Sensor.version
            CreatedDaysAgo        = [math]::Round((Get-Date -Date $Sensor.createdDateTime).TotalDays, 0)
            CreatedDateTime       = $Sensor.createdDateTime
            Id                    = $Sensor.id
        }
    }
}