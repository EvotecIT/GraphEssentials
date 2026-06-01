---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---

# Get-MyDeviceIntune

## SYNOPSIS
Retrieves Intune managed-device inventory and optional Windows Autopilot metadata.

## SYNTAX

```
Get-MyDeviceIntune [<CommonParameters>]
```

## DESCRIPTION
`Get-MyDeviceIntune` returns Intune managed devices with Entra object identifiers, activity dates, compliance state, ownership, enrollment, and management fields.

Use `-IncludeAutopilotInventory` when the caller needs to know whether a Windows device is present in Windows Autopilot. This performs an additional Autopilot inventory read and adds fields such as `AutopilotOnboarded`, `AutopilotDeviceId`, `AutopilotGroupTag`, `AutopilotEnrollmentState`, and `AutopilotLastContacted`.

## EXAMPLES

### Example 1
```powershell
Get-MyDeviceIntune -Type 'AzureAD registered'
```

Returns Intune devices that resolve as Microsoft Entra registered.

### Example 2
```powershell
Get-MyDeviceIntune -Type 'AzureAD joined' -IncludeAutopilotInventory |
    Format-Table Name, OperatingSystem, TrustType, AutopilotOnboarded, AutopilotGroupTag
```

Returns AzureAD joined Intune devices and includes Windows Autopilot matching data.

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.Object
## NOTES

## RELATED LINKS
