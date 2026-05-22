---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---

# Remove-MyAutopilotDevice

## SYNOPSIS
Removes a Windows Autopilot device identity.

## DESCRIPTION
`Remove-MyAutopilotDevice` deletes a Windows Autopilot device identity through Microsoft Graph.
Use it only when the Autopilot registration itself should be removed, not merely the Intune
managed-device record or Microsoft Entra device object.

The cmdlet supports `-WhatIf` and accepts objects returned by `Get-MyDevice` or
`Get-MyDeviceIntune` when they were called with `-IncludeAutopilotInventory`.

Microsoft Graph requires `DeviceManagementServiceConfig.ReadWrite.All` for this action.

## EXAMPLES

### Example 1
```powershell
Get-MyDeviceIntune -IncludeAutopilotInventory |
    Where-Object AutopilotOnboarded |
    Remove-MyAutopilotDevice -WhatIf
```

Preview removing Autopilot identities from enriched Intune device inventory.

### Example 2
```powershell
Remove-MyAutopilotDevice -AutopilotDeviceId '00000000-0000-0000-0000-000000000000'
```

Remove a Windows Autopilot device identity by id.
