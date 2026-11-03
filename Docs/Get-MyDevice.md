---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyDevice
## SYNOPSIS
Gets device information from Microsoft Graph API.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyDevice [[-Type] <string[]>] [[-PropertySet] <string>] [-Synchronized] [-IncludeAutopilotInventory] [-ReportProgress] [<CommonParameters>]
```

## DESCRIPTION
Retrieves device information from Microsoft Graph API and formats it for easy consumption.
Allows filtering by device type (Hybrid, AzureAD joined, etc.) and synchronization status.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyDevice
Returns all devices from the Microsoft Graph API.
```


### EXAMPLE 2
```powershell
PS > Get-MyDevice -Type 'AzureAD joined'
Returns only AzureAD joined devices.
```


### EXAMPLE 3
```powershell
PS > Get-MyDevice -Synchronized
Returns only synchronized devices.
```


## PARAMETERS

### -IncludeAutopilotInventory
When specified, enriches devices with Windows Autopilot identity metadata.

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

### -PropertySet
Full retains the complete device information. Lifecycle omits registered owners.
Computer returns only the dates, identifiers, and owner fields needed for computer
inventory correlation. Computer requests retry individual Graph pages. Owner
continuations are read when present; a possibly truncated owner expansion
makes the inventory fail.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Full, Lifecycle, Computer

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportProgress
Uses retrying Graph pages for any property set and writes page and record
counts to the information stream. If a page remains incomplete, no inventory
is returned. The default non-Computer route retains SDK enumeration.

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

### -Synchronized
Returns only synchronized devices when specified (OnPremisesSyncEnabled is true).

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
Filter devices by type. Valid values are 'Hybrid AzureAD', 'AzureAD joined', 'AzureAD registered', and 'Not available'.

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Hybrid AzureAD, AzureAD joined, AzureAD registered, Not available

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
