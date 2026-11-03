---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyDeviceIntune
## SYNOPSIS
Retrieves Intune device information from Microsoft Graph API.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyDeviceIntune [[-Type] <string[]>] [[-CacheMinutes] <int>] [[-PropertySet] <string>] [-Synchronized] [-Force] [-IncludeDetailedInventory] [-IncludeAutopilotInventory] [-ReportProgress] [<CommonParameters>]
```

## DESCRIPTION
Gets detailed information about devices managed by Intune from the Microsoft Graph API.
Provides data about device compliance, management state, and other device-specific properties.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyDeviceIntune
Returns all Intune managed devices with their properties.
```


## PARAMETERS

### -CacheMinutes
Specifies a value for cache minutes.

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

### -Force
Forces the function to retrieve Azure devices even if they are already cached by using Get-MyDevice cmdlet.

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

### -IncludeAutopilotInventory
When specified, enriches managed devices with Windows Autopilot identity metadata.

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

### -IncludeDetailedInventory
When specified, fetches selected non-default managedDevice properties per device so fields such as
ActivationLockBypassCode, ICCID, UDID, Notes, EthernetMacAddress, and PhysicalMemoryInBytes contain
authoritative values instead of relying on list-response defaults.

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
Selects the managed-device property projection. Full preserves the existing rich output.
Lifecycle requests only the fields needed for inventory correlation and lifecycle actions.
Computer returns only the dates, user fields, and identifiers needed for computer inventory correlation.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Full, Lifecycle, Computer

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportProgress
Uses retrying Graph pages for Entra correlation and the Computer or Lifecycle
Intune inventory, with page and record counts on the information stream.
Full Intune inventory keeps SDK models and their rich property types.
If a required inventory is incomplete, no inventory is returned.

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
When specified, returns only synchronized devices (devices with OnPremisesSyncEnabled set to true).

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
Filters devices by type. Valid values are 'Hybrid AzureAD', 'AzureAD joined', 'AzureAD registered', and 'Not available'.

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
