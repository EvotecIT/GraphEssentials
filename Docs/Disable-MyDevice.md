---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Disable-MyDevice
## SYNOPSIS
Disables a Microsoft Entra device.

## SYNTAX
### ByObject (Default)
```powershell
Disable-MyDevice -InputObject <psobject> [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ById
```powershell
Disable-MyDevice -EntraDeviceObjectId <string> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Disables a Microsoft Entra device by setting AccountEnabled to false.
The function accepts either a device object returned by GraphEssentials cmdlets
or an explicit Entra device object id.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyDevice -Type 'AzureAD registered' | Disable-MyDevice -WhatIf
```


### EXAMPLE 2
```powershell
PS > Disable-MyDevice -EntraDeviceObjectId '00000000-0000-0000-0000-000000000000'
```


## PARAMETERS

### -EntraDeviceObjectId
The Microsoft Entra device object id to disable.

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
Device object returned by Get-MyDevice, Get-MyDeviceIntune, or another object
that exposes EntraDeviceObjectId.

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
