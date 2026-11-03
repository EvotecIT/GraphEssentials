---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Invoke-MyGraphUsageReports
## SYNOPSIS
Generates comprehensive reports for Microsoft 365 service usage.

## SYNTAX
### Period
```powershell
Invoke-MyGraphUsageReports -Period <string> -Report <string[]> [-Online] [-HideHTML] [-FilePath <string>] [-DontSuppress] [<CommonParameters>]
```

### DateTime
```powershell
Invoke-MyGraphUsageReports -DateTime <datetime> -Report <string[]> [-Online] [-HideHTML] [-FilePath <string>] [-DontSuppress] [<CommonParameters>]
```

## DESCRIPTION
Creates HTML reports for various Microsoft 365 services usage data retrieved from Microsoft Graph.
Allows filtering by date range and can generate reports for specific services or all available services.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Invoke-MyGraphUsageReports -Period 30 -Report 'All' -FilePath "C:\Reports\UsageReport.html" -Online
Generates reports for all available usage data for the last 30 days and opens the report in the default browser.
```


### EXAMPLE 2
```powershell
PS > Invoke-MyGraphUsageReports -DateTime "2023-01-01" -Report 'TeamsUserActivityUserDetail','TeamsDeviceUsageUserDetail' -FilePath "C:\Reports\TeamsUsage.html"
Generates specific Teams usage reports for the specified date and saves the report to the specified path.
```


## PARAMETERS

### -DateTime
Specifies a specific date to retrieve usage data for. Reports will cover data for the
specified date where supported. Activation reports are unfiltered; reports that
require a period use D7 when given a date. The HTML report shows the effective selection.
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

### -DontSuppress
When specified, returns the reporting data object after generating reports.

```yaml
Type: SwitchParameter
Parameter Sets: Period, DateTime
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FilePath
The path where the HTML report will be saved. If not provided, a temporary file path will be used.

```yaml
Type: String
Parameter Sets: Period, DateTime
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -HideHTML
When specified, suppresses automatic opening of the HTML report in the default browser.

```yaml
Type: SwitchParameter
Parameter Sets: Period, DateTime
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Online
When specified, opens the generated report in the default web browser.

```yaml
Type: SwitchParameter
Parameter Sets: Period, DateTime
Aliases: None
Possible values:

Required: False
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
Specifies which usage reports to generate. Can be a list of specific report names or 'All' to
generate all available reports. See ValidateSet for all available report options.

```yaml
Type: String[]
Parameter Sets: Period, DateTime
Aliases: None
Possible values: All, EmailActivityCounts, EmailActivityUserCounts, EmailActivityUserDetail, EmailAppUsageAppsUserCounts, EmailAppUsageUserCounts, EmailAppUsageUserDetail, EmailAppUsageVersionsUserCounts, MailboxUsageDetail, MailboxUsageMailboxCounts, MailboxUsageQuotaStatusMailboxCounts, MailboxUsageStorage, Office365ActivationCounts, Office365ActivationsUserCounts, Office365ActivationsUserDetail, Office365ActiveUserCounts, Office365ActiveUserDetail, Office365GroupsActivityCounts, Office365GroupsActivityDetail, Office365GroupsActivityFileCounts, Office365GroupsActivityGroupCounts, Office365GroupsActivityStorage, Office365ServicesUserCounts, OneDriveActivityFileCounts, OneDriveActivityUserCounts, OneDriveActivityUserDetail, OneDriveUsageAccountCounts, OneDriveUsageAccountDetail, OneDriveUsageFileCounts, OneDriveUsageStorage, SharePointActivityFileCounts, SharePointActivityPages, SharePointActivityUserCounts, SharePointActivityUserDetail, SharePointSiteUsageDetail, SharePointSiteUsageFileCounts, SharePointSiteUsagePages, SharePointSiteUsageSiteCounts, SharePointSiteUsageStorage, SkypeForBusinessActivityCounts, SkypeForBusinessActivityUserCounts, SkypeForBusinessActivityUserDetail, SkypeForBusinessDeviceUsageDistributionUserCounts, SkypeForBusinessDeviceUsageUserCounts, SkypeForBusinessDeviceUsageUserDetail, SkypeForBusinessOrganizerActivityCounts, SkypeForBusinessOrganizerActivityMinuteCounts, SkypeForBusinessOrganizerActivityUserCounts, SkypeForBusinessParticipantActivityCounts, SkypeForBusinessParticipantActivityMinuteCounts, SkypeForBusinessParticipantActivityUserCounts, SkypeForBusinessPeerToPeerActivityCounts, SkypeForBusinessPeerToPeerActivityMinuteCounts, SkypeForBusinessPeerToPeerActivityUserCounts, TeamsDeviceUsageDistributionUserCounts, TeamsDeviceUsageUserCounts, TeamsDeviceUsageUserDetail, TeamsUserActivityCounts, TeamsUserActivityUserCounts, TeamsUserActivityUserDetail, YammerActivityCounts, YammerActivityUserCounts, YammerActivityUserDetail, YammerDeviceUsageDistributionUserCounts, YammerDeviceUsageUserCounts, YammerDeviceUsageUserDetail, YammerGroupsActivityCounts, YammerGroupsActivityDetail, YammerGroupsActivityGroupCounts

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
