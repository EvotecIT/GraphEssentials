---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Invoke-MyDeviceRetire
## SYNOPSIS
Retires an Intune managed device.

## SYNTAX
### ByObject (Default)
```powershell
Invoke-MyDeviceRetire -InputObject <psobject> [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ById
```powershell
Invoke-MyDeviceRetire -ManagedDeviceId <string> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Retires an Intune managed device using Microsoft Graph.
The function accepts either a device object returned by Get-MyDeviceIntune
or an explicit Intune managed device id.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyDeviceIntune -Type 'AzureAD registered' | Invoke-MyDeviceRetire -WhatIf
```


### EXAMPLE 2
```powershell
PS > Invoke-MyDeviceRetire -ManagedDeviceId '00000000-0000-0000-0000-000000000000'
```


## PARAMETERS

### -InputObject
Device object returned by Get-MyDeviceIntune or another object
that exposes ManagedDeviceId.

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

### -ManagedDeviceId
The Intune managed device id to retire.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `PSObject`

## OUTPUTS

- `None`

## RELATED LINKS

- None
