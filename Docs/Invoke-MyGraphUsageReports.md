---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---

# Invoke-MyGraphUsageReports

## SYNOPSIS
{{ Fill in the Synopsis }}

## SYNTAX

### Period
```
Invoke-MyGraphUsageReports -Period <String> -Report <String[]> [-Online] [-HideHTML] [-FilePath <String>]
 [-DontSuppress] [<CommonParameters>]
```

### DateTime
```
Invoke-MyGraphUsageReports -DateTime <DateTime> -Report <String[]> [-Online] [-HideHTML] [-FilePath <String>]
 [-DontSuppress] [<CommonParameters>]
```

## DESCRIPTION
{{ Fill in the Description }}

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -DateTime
{{ Fill DateTime Description }}

```yaml
Type: DateTime
Parameter Sets: DateTime
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DontSuppress
{{ Fill DontSuppress Description }}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FilePath
{{ Fill FilePath Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -HideHTML
{{ Fill HideHTML Description }}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Online
{{ Fill Online Description }}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Period
{{ Fill Period Description }}

```yaml
Type: String
Parameter Sets: Period
Aliases:
Accepted values: 7, 30, 90, 180

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Report
{{ Fill Report Description }}

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:
Accepted values: All, EmailActivityCounts, EmailActivityUserCounts, EmailActivityUserDetail, EmailAppUsageAppsUserCounts, EmailAppUsageUserCounts, EmailAppUsageUserDetail, EmailAppUsageVersionsUserCounts, MailboxUsageDetail, MailboxUsageMailboxCounts, MailboxUsageQuotaStatusMailboxCounts, MailboxUsageStorage, Office365ActivationCounts, Office365ActivationsUserCounts, Office365ActivationsUserDetail, Office365ActiveUserCounts, Office365ActiveUserDetail, Office365GroupsActivityCounts, Office365GroupsActivityDetail, Office365GroupsActivityFileCounts, Office365GroupsActivityGroupCounts, Office365GroupsActivityStorage, Office365ServicesUserCounts, OneDriveActivityFileCounts, OneDriveActivityUserCounts, OneDriveActivityUserDetail, OneDriveUsageAccountCounts, OneDriveUsageAccountDetail, OneDriveUsageFileCounts, OneDriveUsageStorage, SharePointActivityFileCounts, SharePointActivityPages, SharePointActivityUserCounts, SharePointActivityUserDetail, SharePointSiteUsageDetail, SharePointSiteUsageFileCounts, SharePointSiteUsagePages, SharePointSiteUsageSiteCounts, SharePointSiteUsageStorage, SkypeForBusinessActivityCounts, SkypeForBusinessActivityUserCounts, SkypeForBusinessActivityUserDetail, SkypeForBusinessDeviceUsageDistributionUserCounts, SkypeForBusinessDeviceUsageUserCounts, SkypeForBusinessDeviceUsageUserDetail, SkypeForBusinessOrganizerActivityCounts, SkypeForBusinessOrganizerActivityMinuteCounts, SkypeForBusinessOrganizerActivityUserCounts, SkypeForBusinessParticipantActivityCounts, SkypeForBusinessParticipantActivityMinuteCounts, SkypeForBusinessParticipantActivityUserCounts, SkypeForBusinessPeerToPeerActivityCounts, SkypeForBusinessPeerToPeerActivityMinuteCounts, SkypeForBusinessPeerToPeerActivityUserCounts, TeamsDeviceUsageDistributionUserCounts, TeamsDeviceUsageUserCounts, TeamsDeviceUsageUserDetail, TeamsUserActivityCounts, TeamsUserActivityUserCounts, TeamsUserActivityUserDetail, YammerActivityCounts, YammerActivityUserCounts, YammerActivityUserDetail, YammerDeviceUsageDistributionUserCounts, YammerDeviceUsageUserCounts, YammerDeviceUsageUserDetail, YammerGroupsActivityCounts, YammerGroupsActivityDetail, YammerGroupsActivityGroupCounts

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.Object
## NOTES

## RELATED LINKS
