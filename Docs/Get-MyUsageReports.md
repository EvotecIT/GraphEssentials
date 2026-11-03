---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyUsageReports
## SYNOPSIS
Retrieves usage report data from Microsoft Graph API.

## SYNTAX
### Period (Default)
```powershell
Get-MyUsageReports -Period <string> -Report <string> [<CommonParameters>]
```

### DateTime
```powershell
Get-MyUsageReports -DateTime <datetime> -Report <string> [<CommonParameters>]
```

## DESCRIPTION
Gets detailed usage reports for various Microsoft 365 services via the Microsoft Graph API.
Supports retrieving data for specific time periods or dates and allows filtering by report type.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyUsageReports -Period 30 -Report 'TeamsUserActivityUserDetail'
Returns Teams user activity details for the last 30 days.
```


### EXAMPLE 2
```powershell
PS > Get-MyUsageReports -DateTime "2023-01-01" -Report 'Office365ActivationsUserDetail'
Returns unfiltered Office 365 activation details and warns that this report does not support date filtering.
```


## PARAMETERS

### -DateTime
Specifies a specific date to retrieve usage data for. Format should be a valid DateTime.
Must be used when not using Period parameter.

```yaml
Type: DateTime
Parameter Sets: DateTime
Aliases: None
Possible values:

Required: True
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Period
Specifies the reporting period in days. Valid values are '7', '30', '90', '180'.
Must be used when not using DateTime parameter.

```yaml
Type: String
Parameter Sets: Period
Aliases: None
Possible values: 7, 30, 90, 180

Required: True
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Report
Specifies which usage report to retrieve. See ValidateSet for all available report options.

```yaml
Type: String
Parameter Sets: Period, DateTime
Aliases: None
Possible values: EmailActivityCounts, EmailActivityUserCounts, EmailActivityUserDetail, EmailAppUsageAppsUserCounts, EmailAppUsageUserCounts, EmailAppUsageUserDetail, EmailAppUsageVersionsUserCounts, MailboxUsageDetail, MailboxUsageMailboxCounts, MailboxUsageQuotaStatusMailboxCounts, MailboxUsageStorage, Office365ActivationCounts, Office365ActivationsUserCounts, Office365ActivationsUserDetail, Office365ActiveUserCounts, Office365ActiveUserDetail, Office365GroupsActivityCounts, Office365GroupsActivityDetail, Office365GroupsActivityFileCounts, Office365GroupsActivityGroupCounts, Office365GroupsActivityStorage, Office365ServicesUserCounts, OneDriveActivityFileCounts, OneDriveActivityUserCounts, OneDriveActivityUserDetail, OneDriveUsageAccountCounts, OneDriveUsageAccountDetail, OneDriveUsageFileCounts, OneDriveUsageStorage, SharePointActivityFileCounts, SharePointActivityPages, SharePointActivityUserCounts, SharePointActivityUserDetail, SharePointSiteUsageDetail, SharePointSiteUsageFileCounts, SharePointSiteUsagePages, SharePointSiteUsageSiteCounts, SharePointSiteUsageStorage, SkypeForBusinessActivityCounts, SkypeForBusinessActivityUserCounts, SkypeForBusinessActivityUserDetail, SkypeForBusinessDeviceUsageDistributionUserCounts, SkypeForBusinessDeviceUsageUserCounts, SkypeForBusinessDeviceUsageUserDetail, SkypeForBusinessOrganizerActivityCounts, SkypeForBusinessOrganizerActivityMinuteCounts, SkypeForBusinessOrganizerActivityUserCounts, SkypeForBusinessParticipantActivityCounts, SkypeForBusinessParticipantActivityMinuteCounts, SkypeForBusinessParticipantActivityUserCounts, SkypeForBusinessPeerToPeerActivityCounts, SkypeForBusinessPeerToPeerActivityMinuteCounts, SkypeForBusinessPeerToPeerActivityUserCounts, TeamsDeviceUsageDistributionUserCounts, TeamsDeviceUsageUserCounts, TeamsDeviceUsageUserDetail, TeamsUserActivityCounts, TeamsUserActivityUserCounts, TeamsUserActivityUserDetail, YammerActivityCounts, YammerActivityUserCounts, YammerActivityUserDetail, YammerDeviceUsageDistributionUserCounts, YammerDeviceUsageUserCounts, YammerDeviceUsageUserDetail, YammerGroupsActivityCounts, YammerGroupsActivityDetail, YammerGroupsActivityGroupCounts

Required: True
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `None`

## RELATED LINKS

- None
