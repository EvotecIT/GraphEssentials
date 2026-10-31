---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Invoke-MyAppCertificateRotation
## SYNOPSIS
Advances opt-in application certificate renewal using the Microsoft Graph PowerShell SDK.

## SYNTAX
### __AllParameterSets
```powershell
Invoke-MyAppCertificateRotation [-Path] <string> [-Reconcile] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Renews the enrolled software certificate when due, verifies a fresh token using the replacement,
activates its protected profile reference, and retires the previous key after overlap. Uses the
current app-only SDK connection for the enrolled application and disables SDK write retries only
for each mutation. Run maintenance in a dedicated PowerShell process, not parallel SDK runspaces.
After Action Activated, load the new active certificate and reconnect long-running SDK consumers.
This command does not replace the caller's SDK connection or dispose its certificate.
Interrupted writes remain held until explicit reconciliation; importing or connecting never rotates.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Invoke-MyAppCertificateRotation -Path $profilePath -WhatIf
Previews the next maintenance action without generating a certificate, contacting Graph or writing files.
```


### EXAMPLE 2
```powershell
PS > $result = Invoke-MyAppCertificateRotation -Path $profilePath -Confirm:$false
Advances a scheduled renewal. Action Activated indicates that the script should reload and reconnect.
```


### EXAMPLE 3
```powershell
PS > Invoke-MyAppCertificateRotation -Path $profilePath -Reconcile
Confirms remote public-key evidence before resolving a saved in-flight operation.
```


## PARAMETERS

### -Path
Profile directory created by Register-MyAppCertificateRotation, under the same Windows account.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Reconcile
Reads the application's public certificate evidence with Get-MgApplication and repairs only local
progress after an interrupted write. Requires an SDK connection in the profile tenant with permission
to read that application. No remote write occurs in this mode; reconnect as the enrolled application
before ordinary maintenance. A missing or ambiguous replacement keeps the hold.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `System.Management.Automation.PSCustomObject. Safe profile metadata and the action taken.`

## RELATED LINKS

- None
