function Get-MyDefenderSensor {
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