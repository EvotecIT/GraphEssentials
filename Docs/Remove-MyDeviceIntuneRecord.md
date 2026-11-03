---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Remove-MyDeviceIntuneRecord
## SYNOPSIS
Removes an Intune managed device record.

## SYNTAX
### ByObject (Default)
```powershell
Remove-MyDeviceIntuneRecord -InputObject <psobject> [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ById
```powershell
Remove-MyDeviceIntuneRecord -ManagedDeviceId <string> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Deletes an Intune managed device record using Microsoft Graph.
The function accepts either a device object returned by Get-MyDeviceIntune
or an explicit Intune managed device id.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyDeviceIntune -Type 'AzureAD registered' | Remove-MyDeviceIntuneRecord -WhatIf
```


### EXAMPLE 2
```powershell
PS > Remove-MyDeviceIntuneRecord -ManagedDeviceId '00000000-0000-0000-0000-000000000000'
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
The Intune managed device id to remove.

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
