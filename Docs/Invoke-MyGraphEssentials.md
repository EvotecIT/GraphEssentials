---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Invoke-MyGraphEssentials
## SYNOPSIS
Generates comprehensive reports for various Microsoft Graph resources.

## SYNTAX
### __AllParameterSets
```powershell
Invoke-MyGraphEssentials [[-Type] <string[]>] [-FilePath <string>] [-PassThru] [-HideHTML] [-HideSteps] [-ShowError] [-ShowWarning] [-Online] [-SplitReports] [-PostProcess <scriptblock>] [-AppsDetailLevel <string>] [-AppsApplicationType <string>] [-IncludeOwnerDiagnostics] [<CommonParameters>]
```

## DESCRIPTION
Creates HTML reports for Microsoft Graph resources such as apps, devices, roles, and users.
Reports can be customized and filtered based on the specified types and can be output as a single
report or split into multiple reports.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Invoke-MyGraphEssentials -Type DevicesIntune, Roles, RolesUsers -FilePath "C:\Reports\GraphReport.html" -Online
Generates a combined report for devices, roles, and role users, and opens it in the default web browser.
```


### EXAMPLE 2
```powershell
PS > Invoke-MyGraphEssentials -Type Apps, AppsCredentials -FilePath "C:\Reports\Apps.html" -SplitReports
Generates separate reports for Apps and AppsCredentials in individual HTML files.
```


## PARAMETERS

### -AppsApplicationType
Filters which Service Principals are processed by Get-MyApp:
- All (default), AppRegistrations (First Party), EnterpriseApps (Third Party), MicrosoftApps, ManagedIdentities

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: All, AppRegistrations, EnterpriseApps, MicrosoftApps, ManagedIdentities

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AppsDetailLevel
Controls how much data Apps collection gathers:
- Full    : current behaviour (delegated grants, owners, comprehensive activity)
- Light   : skips delegated permission grants and comprehensive activity (keeps owners)
- Minimal : skips delegated permission grants, owners and comprehensive activity (expiry-only)

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Full, Light, Minimal

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
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -HideHTML
When specified, doesn't display the HTML report in the default browser.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -HideSteps
When specified, hides the step-by-step details in the console output.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeOwnerDiagnostics
When set, AppsOverview renders extra owner-diagnostics columns (OwnerResolvedId/Email/Status, etc.).
Defaults to off to keep the generic report lean.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
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
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
When specified, returns the reporting data object after generating reports.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PostProcess
Optional scriptblock invoked after data collection and before HTML generation.
The scriptblock receives $Script:Reporting as its only argument and can modify it to affect output.

```yaml
Type: ScriptBlock
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowError
When specified, shows safe error notices in the console output. Collection problems always appear in HTML.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowWarning
When specified, shows safe warning notices in the console output. Collection problems always appear in HTML.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SplitReports
When specified, generates separate HTML files for each report type instead of a combined report.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Type
Array of report types to generate. Valid values include DevicesIntune, Roles, RolesUsers, Apps, etc.

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 0
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
