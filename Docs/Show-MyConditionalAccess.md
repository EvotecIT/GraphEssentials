---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Show-MyConditionalAccess
## SYNOPSIS
Generates an HTML report for conditional access policies.

## SYNTAX
### __AllParameterSets
```powershell
Show-MyConditionalAccess [-FilePath] <string> [-Online] [-ShowHTML] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves conditional access policies and displays them in an HTML report using PSWriteHTML.
The report includes information about policy categorization, authentication strength policies, and usage statistics.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Show-MyConditionalAccess -FilePath "C:\Reports\ConditionalAccess.html"
```

Generates a conditional access policies report and saves it to the specified path.

### EXAMPLE 2
```powershell
PS > Show-MyConditionalAccess -FilePath "C:\Reports\ConditionalAccess.html" -Online
```

Generates a conditional access policies report, saves it to the specified path, and opens it in the default browser.

## PARAMETERS

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
