function Get-MyUsageReports {
    <#
    .SYNOPSIS
    Retrieves usage report data from Microsoft Graph API.

    .DESCRIPTION
    Gets detailed usage reports for various Microsoft 365 services via the Microsoft Graph API.
    Supports retrieving data for specific time periods or dates and allows filtering by report type.

    .PARAMETER Period
    Specifies the reporting period in days. Valid values are '7', '30', '90', '180'.
    Must be used when not using DateTime parameter.

    .PARAMETER DateTime
    Specifies a specific date to retrieve usage data for. Format should be a valid DateTime.
    Must be used when not using Period parameter.

    .PARAMETER Report
    Specifies which usage report to retrieve. See ValidateSet for all available report options.

    .EXAMPLE
    Get-MyUsageReports -Period 30 -Report 'TeamsUserActivityUserDetail'
    Returns Teams user activity details for the last 30 days.

    .EXAMPLE
    Get-MyUsageReports -DateTime "2023-01-01" -Report 'Office365ActivationsUserDetail'
    Returns Office 365 activation details for the specified date.

    .NOTES
    This function requires Microsoft Graph API permissions, typically Reports.Read.All.
    The data returned varies based on the report type requested.
    #>
    [cmdletBinding(DefaultParameterSetName = "Period")]
    param(
        [parameter(ParameterSetName = 'Period', Mandatory)][ValidateSet('7', '30', '90', '180')][string] $Period,
        [parameter(ParameterSetName = 'DateTime', Mandatory)][DateTime] $DateTime, # last 30 days YYYY-MM-DD

        [parameter(Mandatory)][string][ValidateSet(
            'EmailActivityCounts',
            'EmailActivityUserCounts',
            'EmailActivityUserDetail',
            'EmailAppUsageAppsUserCounts',
            'EmailAppUsageUserCounts',
            'EmailAppUsageUserDetail',
            'EmailAppUsageVersionsUserCounts',
            'MailboxUsageDetail',
            'MailboxUsageMailboxCounts',
            'MailboxUsageQuotaStatusMailboxCounts',
            'MailboxUsageStorage',
            'Office365ActivationCounts',
            'Office365ActivationsUserCounts',
            'Office365ActivationsUserDetail',
            'Office365ActiveUserCounts',
            'Office365ActiveUserDetail',
            'Office365GroupsActivityCounts',
            'Office365GroupsActivityDetail',
            'Office365GroupsActivityFileCounts',
            'Office365GroupsActivityGroupCounts',
            'Office365GroupsActivityStorage',
            'Office365ServicesUserCounts',
            'OneDriveActivityFileCounts',
            'OneDriveActivityUserCounts',
            'OneDriveActivityUserDetail',
            'OneDriveUsageAccountCounts',
            'OneDriveUsageAccountDetail',
            'OneDriveUsageFileCounts',
            'OneDriveUsageStorage',
            'SharePointActivityFileCounts',
            'SharePointActivityPages',
            'SharePointActivityUserCounts',
            'SharePointActivityUserDetail',
            'SharePointSiteUsageDetail',
            'SharePointSiteUsageFileCounts',
            'SharePointSiteUsagePages',
            'SharePointSiteUsageSiteCounts',
            'SharePointSiteUsageStorage',
            'SkypeForBusinessActivityCounts',
            'SkypeForBusinessActivityUserCounts',
            'SkypeForBusinessActivityUserDetail',
            'SkypeForBusinessDeviceUsageDistributionUserCounts',
            'SkypeForBusinessDeviceUsageUserCounts',
            'SkypeForBusinessDeviceUsageUserDetail',
            'SkypeForBusinessOrganizerActivityCounts',
            'SkypeForBusinessOrganizerActivityMinuteCounts',
            'SkypeForBusinessOrganizerActivityUserCounts',
            'SkypeForBusinessParticipantActivityCounts',
            'SkypeForBusinessParticipantActivityMinuteCounts',
            'SkypeForBusinessParticipantActivityUserCounts',
            'SkypeForBusinessPeerToPeerActivityCounts',
            'SkypeForBusinessPeerToPeerActivityMinuteCounts',
            'SkypeForBusinessPeerToPeerActivityUserCounts',
            'TeamsDeviceUsageDistributionUserCounts',
            'TeamsDeviceUsageUserCounts',
            'TeamsDeviceUsageUserDetail',
            'TeamsUserActivityCounts',
            'TeamsUserActivityUserCounts',
            'TeamsUserActivityUserDetail',
            'YammerActivityCounts',
            'YammerActivityUserCounts',
            'YammerActivityUserDetail',
            'YammerDeviceUsageDistributionUserCounts',
            'YammerDeviceUsageUserCounts',
            'YammerDeviceUsageUserDetail',
            'YammerGroupsActivityCounts',
            'YammerGroupsActivityDetail',
            'YammerGroupsActivityGroupCounts'
        )] $Report
    )
    if ($Period) {
        Write-Verbose -Message "Get-MyUsageReports - Report: $Report, Period: $Period"
        $DayPeriod = "D$Period"
        $Type = "(period='$DayPeriod')"
    } else {
        Write-Verbose -Message "Get-MyUsageReports - Report: $Report, DateTime: $DateTime"
        # last 30 days YYYY-MM-DD
        $DateTimeConverted = $DateTime.ToUniversalTime().ToString('yyyy-MM-dd')
        $Type = "(date=$DateTimeConverted)"
    }

    # main url
    $Url = "https://graph.microsoft.com/v1.0/reports/get$Report"

    # lets filter out the reports that do not support filtering, and apply some logic to let user get the data anyways
    if ($Report -in 'Office365ActivationCounts', 'Office365ActivationsUserCounts', 'Office365ActivationsUserDetail') {
        Write-Warning -Message "Get-MyUsageReports - $Report does not support filtering. Processing all data."
    } elseif ($Report -eq 'MailboxUsageDetail') {
        if ($Period) {
            $Url += "$Type"
        } else {
            Write-Warning -Message "Get-MyUsageReports - $Report does not support date filtering. Processing all data for period of 7 days."
            $Url += "(period='D7')"
            $Type = "(period='D7')"
        }
    } else {
        if ($Report -match 'Counts$|Pages$|Storage$') {
            if ($Period) {
                $Url += "$Type"
            } else {
                Write-Warning -Message "Get-MyUsageReports - $Report ending with Counts, Pages or Storage do not support date filtering. Processing data for last 7 days."
                $Url += "(period='D7')"
            }
        } else {
            $Url += "$Type"
        }
    }

    $TemporaryFile = [System.IO.Path]::GetTempFileName()

    try {
        Invoke-MgGraphRequest -Method GET -Uri $Url -ContentType "application/json" -OutputFilePath $TemporaryFile -ErrorAction Stop
    } catch {
        $ErrorDefault = $_.Exception.Message
        $ErrorDetails = $_.ErrorDetails.Message
        # get only the last line of the error message
        if ($ErrorDetails) {
            $ErrorDetails = $ErrorDetails.Split("`n")[-1]
            Try {
                $ErrorJSON = $ErrorDetails | ConvertFrom-Json -ErrorAction Stop
            } catch {
                Write-Warning -Message "Get-MyUsageReports - Error when requesting data for $Report $Type. Error: $ErrorDefault"
            }
            try {
                $NestedError = $ErrorJSON.error.message | ConvertFrom-Json -ErrorAction Stop
                $FinalErrorMessage = $NestedError.error.message
                Write-Warning -Message "Get-MyUsageReports - Error when requesting data for $Report $Type. Error: $FinalErrorMessage"
            } catch {
                Write-Warning -Message "Get-MyUsageReports - Error when requesting data for $Report $Type. Error: $ErrorDefault"
            }
        } else {
            Write-Warning -Message "Get-MyUsageReports - Error when requesting data for $Report $Type. Error: $ErrorDefault"
        }
    }
    if (Test-Path -LiteralPath $TemporaryFile) {
        try {
            $CSV = Import-Csv -LiteralPath $TemporaryFile -ErrorAction Stop -Encoding Unicode
            $CSV
        } catch {
            Write-Warning -Message "Get-MyUsageReports - Error when importing data $Report $Type. Error: $($_.Exception.Message)"
        }
        try {
            Remove-Item -LiteralPath $TemporaryFile -ErrorAction Stop
        } catch {
            Write-Warning -Message "Get-MyUsageReports - Error when removing temporary file $Report $Type. Error: $($_.Exception.Message)"
        }
    }
}