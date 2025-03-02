function Invoke-MyGraphUsageReports {
    <#
    .SYNOPSIS
    Generates comprehensive reports for Microsoft 365 service usage.

    .DESCRIPTION
    Creates HTML reports for various Microsoft 365 services usage data retrieved from Microsoft Graph.
    Allows filtering by date range and can generate reports for specific services or all available services.

    .PARAMETER Period
    Specifies the reporting period in days. Valid values are '7', '30', '90', '180'.
    Must be used when not using DateTime parameter.

    .PARAMETER DateTime
    Specifies a specific date to retrieve usage data for. Reports will cover data for the
    specified date (based on data availability from Microsoft Graph).
    Must be used when not using Period parameter.

    .PARAMETER Report
    Specifies which usage reports to generate. Can be a list of specific report names or 'All' to
    generate all available reports. See ValidateSet for all available report options.

    .PARAMETER Online
    When specified, opens the generated report in the default web browser.

    .PARAMETER HideHTML
    When specified, suppresses automatic opening of the HTML report in the default browser.

    .PARAMETER FilePath
    The path where the HTML report will be saved. If not provided, a temporary file path will be used.

    .PARAMETER DontSuppress
    When specified, returns the reporting data object after generating reports.

    .EXAMPLE
    Invoke-MyGraphUsageReports -Period 30 -Report 'All' -FilePath "C:\Reports\UsageReport.html" -Online
    Generates reports for all available usage data for the last 30 days and opens the report in the default browser.

    .EXAMPLE
    Invoke-MyGraphUsageReports -DateTime "2023-01-01" -Report 'TeamsUserActivityUserDetail','TeamsDeviceUsageUserDetail' -FilePath "C:\Reports\TeamsUsage.html"
    Generates specific Teams usage reports for the specified date and saves the report to the specified path.

    .NOTES
    This function requires appropriate Microsoft Graph permissions, typically Reports.Read.All.
    Some report types may only have data available for certain time periods.
    #>
    [CmdletBinding()]
    param(
        [parameter(ParameterSetName = 'Period', Mandatory)][ValidateSet('7', '30', '90', '180')][string] $Period,
        [parameter(ParameterSetName = 'DateTime', Mandatory)][DateTime] $DateTime, # last 30 days YYYY-MM-DD

        [parameter(Mandatory)][string[]][ValidateSet(
            'All',
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
        )] $Report,
        [switch] $Online,
        [switch] $HideHTML,
        [string] $FilePath,
        [switch] $DontSuppress
    )
    $Script:Reporting = [ordered] @{}
    $Script:Reporting['Version'] = Get-GitHubVersion -Cmdlet 'Invoke-MyGraphEssentials' -RepositoryOwner 'evotecit' -RepositoryName 'GraphEssentials'
    $Script:Reporting['Reports'] = [ordered] @{}

    if ($Report -contains 'All') {
        $ParameterList = (Get-Command -Name Get-MyUsageReports).Parameters
        $Report = $ParameterList["Report"].Attributes.ValidValues
    }

    foreach ($R in $Report) {
        $Splat = @{
            Report   = $R
            Period   = $Period
            DateTime = $DateTime
        }
        Remove-EmptyValue -Hashtable $Splat
        $Script:Reporting['Reports'][$R] = Get-MyUsageReports @Splat
    }
    $newHTMLReportGraphUsageSplat = @{
        Reports  = $Script:Reporting['Reports']
        Online   = $Online
        HideHTML = $HideHTML
        FilePath = $FilePath
    }
    New-HTMLReportGraphUsage @newHTMLReportGraphUsageSplat

    if ($DontSuppress) {
        $Script:Reporting
    }
}