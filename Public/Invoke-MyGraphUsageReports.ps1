function Invoke-MyGraphUsageReports {
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