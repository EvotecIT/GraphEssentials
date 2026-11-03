---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Show-MyApp
## SYNOPSIS
Generates an HTML report for Azure AD applications, their credentials, permissions, and activity.

## SYNTAX
### __AllParameterSets
```powershell
Show-MyApp [-FilePath] <string> [[-ApplicationType] <string>] [[-DetailLevel] <string>] [-Online] [-ShowHTML] [-IncludeRealtimeSignIns] [-IncludeDetailedSignInLogs] [-IncludeFederated] [<CommonParameters>]
```

## DESCRIPTION
Creates a comprehensive HTML report displaying information about Azure AD/Entra applications,
including owners, credential details, source (first/third party), permissions (delegated/application),
sign-in activity, and credential expiry. Includes summary statistics.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Show-MyApp -FilePath "C:\Reports\Applications.html"
Generates an applications report and saves it to the specified path.
```


### EXAMPLE 2
```powershell
PS > Show-MyApp -FilePath "C:\Reports\Applications.html" -Online
Generates an applications report, saves it to the specified path, and opens it in the default browser.
```


## PARAMETERS

### -ApplicationType
Specifies the type of applications to include in the report.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: All, AppRegistrations, EnterpriseApps, MicrosoftApps, ManagedIdentities

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DetailLevel
Specifies a value for detail level.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Full, Light, Minimal

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FilePath
The path where the HTML report will be saved.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeDetailedSignInLogs
Specifies the include detailed sign in logs switch.

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

### -IncludeFederated
Specifies the include federated switch.

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

### -IncludeRealtimeSignIns
Specifies the include realtime sign ins switch.

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
If specified, opens the HTML report in the default browser after generation.

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

### -ShowHTML
If specified, displays the HTML content in the PowerShell console after generation.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `None`

## RELATED LINKS

- None
