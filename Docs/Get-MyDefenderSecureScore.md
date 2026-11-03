---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyDefenderSecureScore
## SYNOPSIS
Retrieves Microsoft Defender secure score information.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyDefenderSecureScore [-IncludeScoreSummary] [-All] [<CommonParameters>]
```

## DESCRIPTION
Gets detailed information about Microsoft Defender secure scores from the Microsoft Graph Security API.
Returns secure score metrics including current score, max score, and individual control scores.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyDefenderSecureScore
Returns the most recent Microsoft Defender secure score details.
```


### EXAMPLE 2
```powershell
PS > Get-MyDefenderSecureScore -IncludeScoreSummary
Returns the most recent Microsoft Defender secure score with a summary of metrics.
```


### EXAMPLE 3
```powershell
PS > Get-MyDefenderSecureScore -All
Returns all historical Microsoft Defender secure scores.
```


## PARAMETERS

### -All
When specified, retrieves all historical secure scores instead of just the most recent one.

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

### -IncludeScoreSummary
When specified, includes a summary of the secure score metrics in the output.

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
