function Get-MyDefenderHealthIssues {
    <#
    .SYNOPSIS
    Retrieves health issues from Microsoft Graph Security API.

    .DESCRIPTION
    This function queries the Microsoft Graph Security API to retrieve health issues based on various filters such as status, health issue type, severity, and sensor DNS name.

    .PARAMETER Status
    The status of the health issues to retrieve. Valid values are 'open' and 'closed'.

    .PARAMETER HealthIssueType
    The type of health issues to retrieve. Valid values are 'global' and 'sensor'.

    .PARAMETER Severity
    The severity of the health issues to retrieve. Valid values are 'high', 'medium', and 'low'.

    .PARAMETER SensorDNSName
    The DNS name of the sensor for which to retrieve health issues. Health issues will be filtered to only include those that end with the specified sensor DNS name.

    .PARAMETER All
    A switch parameter. If specified, all health issues will be retrieved without applying any filters.

    .EXAMPLE
    Get-MyDefenderHealthIssues -Status 'open' -HealthIssueType 'global' -Severity 'high'
    Retrieves all open global health issues with high severity.

    .EXAMPLE
    Get-MyDefenderHealthIssues -SensorDNSName 'contoso.com' -All
    Retrieves all health issues for sensors whose DNS name ends with 'contoso.com', ignoring other filters.

    .NOTES
    Examples of Microsoft Graph Security API queries:
    - See all open health alerts: https://graph.microsoft.com/beta/security/identities/healthIssues?$filter=Status eq 'open'
    - See open Global health alerts: https://graph.microsoft.com/beta/security/identities/healthIssues?$filter=Status eq 'open' and healthIssueType eq 'global'
    - See open sensor health alerts: https://graph.microsoft.com/beta/security/identities/healthIssues?$filter=Status eq 'open' and healthIssueType eq 'sensor'
    - See open health alerts by severity: https://graph.microsoft.com/beta/security/identities/healthIssues?$filter=Status eq 'open' and severity eq 'medium'
    - See open global health alerts that domain name ends with contoso.com: https://graph.microsoft.com/beta/security/identities/healthissues?$filter=Status eq 'open' and healthIssueType eq 'global' and domainNames/any(s:endswith(s,'contoso.com'))
    - See open global health alerts that sensor DNS name ends with contoso.com: https://graph.microsoft.com/beta/security/identities/healthissues?$filter=Status eq 'open' and healthIssueType eq 'global' and sensorDNSNames/any(s:endswith(s,'contoso.com'))
    - See open sensor health alerts with sensor DNS name ends with contoso.corp: https://graph.microsoft.com/beta/security/identities/healthissues?$filter=Status eq 'open' and healthIssueType eq 'sensor' and sensorDNSNames/any(s:endswith(s,'contoso.corp'))

    #>
    [CmdletBinding()]
    param(
        [ValidateSet('open', 'closed')][string] $Status,
        [ValidateSet('global', 'sensor')][string] $HealthIssueType,
        [ValidateSet('high', 'medium', 'low')][string] $Severity,
        [string] $SensorDNSName,
        [switch] $All
    )

    $QueryParameters = [ordered] @{
        All = $All.IsPresent
    }
    if ($Status -and $HealthIssueType -and $Severity) {
        $QueryParameters.Add('$filter', "Status eq '$Status' and healthIssueType eq '$HealthIssueType' and severity eq '$Severity'")
    } elseif ($Status -and $HealthIssueType) {
        $QueryParameters.Add('$filter', "Status eq '$Status' and healthIssueType eq '$HealthIssueType'")
    } elseif ($Status -and $Severity) {
        $QueryParameters.Add('$filter', "Status eq '$Status' and severity eq '$Severity'")
    } elseif ($HealthIssueType -and $Severity) {
        $QueryParameters.Add('$filter', "healthIssueType eq '$HealthIssueType' and severity eq '$Severity'")
    } elseif ($Status) {
        $QueryParameters.Add('$filter', "Status eq '$Status'")
    } elseif ($HealthIssueType) {
        $QueryParameters.Add('$filter', "healthIssueType eq '$HealthIssueType'")
    } elseif ($Severity) {
        $QueryParameters.Add('$filter', "severity eq '$Severity'")
    }
    if ($SensorDNSName) {
        $newFilter = "sensorDNSNames/any(s:endswith(s,'$SensorDNSName'))"
        if ($QueryParameters.Contains('$filter')) {
            $QueryParameters['$filter'] += " and $newFilter"
        } else {
            $QueryParameters.Add('$filter', $newFilter)
        }
    }

    $Data = Get-MgBetaSecurityIdentityHealthIssue @QueryParameters
    $Data | ForEach-Object {
        [PSCustomObject] @{
            DisplayName               = $_.displayName               # : Sensor service failed to start
            Status                    = $_.status                    # : open
            Severity                  = $_.severity                  # : high
            HealthIssueType           = $_.healthIssueType           # : sensor
            CreatedDateTime           = $_.createdDateTime           # : 2024 - 03 - 31 19:05:55
            ModifiedDateTime          = $_.lastModifiedDateTime      # : 2024 - 05 - 03 10:55:20
            SensorDNSNames            = $_.sensorDNSNames            # : { ADRODC.ad.evotec.pl }
            Description               = $_.description               # : The Sensor service on ADRODC.ad.evotec.pl failed to start. It was last seen running on 05 / 03 / 2024 10:24.
            Recommendations           = $_.recommendations           # : { Monitor Sensor logs to understand the root cause for Sensor service failure., Refer to the http: / / aka.ms / mdi / troubleshooting. }
            RecommendedActionCommands = $_.recommendedActionCommands # : {}
            Id                        = $_.id                        # : cafa6f51-be42 - 418a-968b-7cb529fb18ef
            DomainNames               = $_.domainNames               # : {}
            IssueTypeId               = $_.issueTypeId               # :
            AdditionalInformation     = $_.additionalInformation     # : {}
        }
    }
}