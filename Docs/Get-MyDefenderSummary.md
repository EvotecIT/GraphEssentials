---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyDefenderSummary
## SYNOPSIS
Provides a summary of Microsoft Defender for Identity health issues.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyDefenderSummary [<CommonParameters>]
```

## DESCRIPTION
Collects and categorizes Microsoft Defender for Identity health issues into global issues and sensor-specific issues.
This function helps administrators quickly identify and prioritize health issues affecting their MDI deployment.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyDefenderSummary
Returns a summary object containing global and sensor-specific health issues from Microsoft Defender for Identity.
```


## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `None`

## RELATED LINKS

- None
