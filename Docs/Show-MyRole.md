---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Show-MyRole
## SYNOPSIS
Generates a comprehensive HTML report for Azure AD roles, users, and PIM history.

## SYNTAX
### __AllParameterSets
```powershell
Show-MyRole [-FilePath] <string> [[-DaysBack] <int>] [-Online] [-ShowHTML] [-IncludeDisabledUsers] [<CommonParameters>]
```

## DESCRIPTION
This function creates a detailed HTML report that combines role assignments, user role memberships,
and PIM history into a single interactive dashboard. The report includes summary statistics,
detailed tables, and visual representations of your role management landscape.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Show-MyRole -FilePath "C:\Reports\RoleManagement.html"
Generates a role management report and saves it to the specified path.
```


### EXAMPLE 2
```powershell
PS > Show-MyRole -FilePath "C:\Reports\RoleManagement.html" -Online -DaysBack 90
Generates a comprehensive role report with 90 days of PIM history and opens it in the browser.
```


## PARAMETERS

### -DaysBack
Number of days to look back for PIM history. Defaults to 30 days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 1
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

### -IncludeDisabledUsers
If specified, includes disabled users in the user analysis.

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
