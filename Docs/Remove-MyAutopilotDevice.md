---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Remove-MyAutopilotDevice
## SYNOPSIS
Removes a Windows Autopilot device identity.

## SYNTAX
### ByObject (Default)
```powershell
Remove-MyAutopilotDevice -InputObject <psobject> [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ById
```powershell
Remove-MyAutopilotDevice -AutopilotDeviceId <string> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Deletes a Windows Autopilot device identity using Microsoft Graph.
The function accepts either a device object returned by Get-MyDevice or
Get-MyDeviceIntune with Autopilot enrichment, or an explicit Windows
Autopilot device identity id.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyDeviceIntune -IncludeAutopilotInventory |
    Where-Object AutopilotOnboarded |
    Remove-MyAutopilotDevice -WhatIf
```


### EXAMPLE 2
```powershell
PS > Remove-MyAutopilotDevice -AutopilotDeviceId '00000000-0000-0000-0000-000000000000'
```


## PARAMETERS

### -AutopilotDeviceId
The Windows Autopilot device identity id to remove.

```yaml
Type: String
Parameter Sets: ById
Aliases: None
Possible values:

Required: True
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
Device object that exposes AutopilotDeviceId or
WindowsAutopilotDeviceIdentityId.

```yaml
Type: PSObject
Parameter Sets: ByObject
Aliases: None
Possible values:

Required: True
Position: named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `PSObject`

## OUTPUTS

- `None`

## RELATED LINKS

- None
