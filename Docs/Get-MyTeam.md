---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyTeam
## SYNOPSIS
Retrieves Teams information from Microsoft Graph API.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyTeam [-PerOwner] [-AsHashtable] [-RequireCompleteData] [<CommonParameters>]
```

## DESCRIPTION
Gets detailed information about Microsoft Teams including team membership, owner information,
and team settings. Can organize information by team owner and optionally return as a hashtable.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyTeam
Returns a list of all Teams with their properties.
```


### EXAMPLE 2
```powershell
PS > Get-MyTeam -PerOwner
Returns Teams organized by owner.
```


### EXAMPLE 3
```powershell
PS > Get-MyTeam -AsHashtable
Returns Teams information as a hashtable for easier programmatic access.
```


## PARAMETERS

### -AsHashtable
When specified, returns data as a hashtable instead of objects.

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

### -PerOwner
When specified, organizes the output by team owner instead of by team. Teams with no owner
are returned under [No owner], while teams whose owner state could not be read are returned
under [Owner state unavailable].

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

### -RequireCompleteData
Stops with a terminating error when the team list, extended team details, or owner information
cannot be collected. Use this for reports and automation that must not treat incomplete data as
an empty or authoritative result.

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
