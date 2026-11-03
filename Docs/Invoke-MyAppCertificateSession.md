---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Invoke-MyAppCertificateSession
## SYNOPSIS
Runs a workload with the active certificate from an opt-in renewal profile.

## SYNTAX
### __AllParameterSets
```powershell
Invoke-MyAppCertificateSession [-ConnectionParameters] <IDictionary> [[-Rotation] <IDictionary>] [[-ConfigurationDirectory] <string>] [-ScriptBlock] <scriptblock> [[-OnEvent] <scriptblock>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Uses the existing certificate only to enroll a new profile. Later runs load the profile's
active certificate, connect, maintain renewal and reconnect after activation before invoking
the workload. Owns its Graph connection and loaded certificate until the workload completes.
Disabled configuration passes the original connection map to the workload without accessing
credentials or Graph. Bootstrap and maintenance honor WhatIf; ordinary workload reads can run.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Invoke-MyAppCertificateSession -ConnectionParameters $graph -Rotation $settings.CertificateRotation -ConfigurationDirectory $configDirectory -ScriptBlock { param($connection, $status) Get-MyDirectoryUser }
Connects and maintains an enrolled identity, then runs the workload with the active credential.
```


## PARAMETERS

### -ConfigurationDirectory
Base directory for a relative ProfilePath. Required unless ProfilePath is absolute.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConnectionParameters
Existing Graph connection settings, including TenantId and ClientId (or AppId). Certificate
or CertificateThumbprint is required only for enrollment. Secret/access-token connections
cannot be combined with enabled certificate rotation. The supplied map is never modified.

```yaml
Type: IDictionary
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OnEvent
Optional logging callback receiving Event, Message and public Data. It receives no private
certificate, assertion, token or raw provider error. Without it, events use Information.

```yaml
Type: ScriptBlock
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Rotation
JSON-friendly map: Enabled (false by default), ProfilePath, optional bootstrap
ApplicationObjectId/KeyId and CertificateLifetimeDays/RenewBeforeDays/OverlapDays.
The bootstrap identifiers are required only when creating a new profile.

```yaml
Type: IDictionary
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ScriptBlock
Workload called with the effective connection map and a safe maintenance summary. A loaded
Certificate remains valid only inside this callback. Do not retain it or start background work.

```yaml
Type: ScriptBlock
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `The workload's output. Session events and ordinary status contain no private credentials.`

## RELATED LINKS

- None
