---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyDefenderSecureScoreProfile
## SYNOPSIS
Retrieves Microsoft Defender secure score control profiles.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyDefenderSecureScoreProfile [-AsHashtable] [<CommonParameters>]
```

## DESCRIPTION
Gets detailed information about Microsoft Defender secure score control profiles from the Microsoft Graph Security API.
This provides information about each security control that contributes to the overall secure score.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyDefenderSecureScoreProfile
Returns the Microsoft Defender secure score control profiles as an array of objects.
```


### EXAMPLE 2
```powershell
PS > Get-MyDefenderSecureScoreProfile -AsHashtable
Returns the Microsoft Defender secure score control profiles as a hashtable keyed by control ID.
```


## PARAMETERS

### -AsHashtable
When specified, returns the results as a hashtable with control IDs as keys for easier lookup.

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
