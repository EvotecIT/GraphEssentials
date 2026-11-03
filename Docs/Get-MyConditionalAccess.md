---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyConditionalAccess
## SYNOPSIS
Gets conditional access policies from Microsoft Graph and categorizes them.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyConditionalAccess [-IncludeStatistics] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves conditional access policies from Microsoft Graph API and
categorizes them based on their purpose (MFA for admins, block legacy access, etc.).
It can also include statistics about the policies when requested.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyConditionalAccess
```

Returns categorized conditional access policies.

### EXAMPLE 2
```powershell
PS > Get-MyConditionalAccess -IncludeStatistics
```

Returns both statistics and categorized conditional access policies.

## PARAMETERS

### -IncludeStatistics
When specified, includes statistics about the policies in the output.

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
