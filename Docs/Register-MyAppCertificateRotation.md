---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Register-MyAppCertificateRotation
## SYNOPSIS
Enrolls an existing application certificate in an opt-in local renewal profile.

## SYNTAX
### __AllParameterSets
```powershell
Register-MyAppCertificateRotation [-Path] <string> [-TenantId] <guid> [-ClientId] <guid> [-ApplicationObjectId] <guid> [-KeyId] <guid> [-Certificate] <X509Certificate2> [[-RenewBefore] <timespan>] [[-CertificateLifetime] <timespan>] [[-Overlap] <timespan>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Protects an exportable RSA software certificate and renewal policy with Windows DPAPI CurrentUser.
Enrollment creates a new dedicated directory with access restricted to the current account and SYSTEM.
Run enrollment and maintenance as the same Windows account. The supplied certificate must already be
registered on the application. This command does not create applications, consent permissions or change Graph.
Use one profile per application identity and enroll only a credential whose retirement you control.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Register-MyAppCertificateRotation -Path $profilePath -TenantId $tenantId -ClientId $clientId -ApplicationObjectId $objectId -KeyId $keyId -Certificate $certificate
Enrolls an existing certificate under the Windows account that runs the scheduled script.
```


## PARAMETERS

### -ApplicationObjectId
Object ID of the app registration, distinct from its client ID and service principal ID.

```yaml
Type: Guid
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Certificate
Existing valid exportable RSA software certificate with its private key. Caller retains ownership.

```yaml
Type: X509Certificate2
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CertificateLifetime
Lifetime of each generated replacement certificate. Defaults to 30 days and must exceed RenewBefore plus Overlap.

```yaml
Type: TimeSpan
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 7
Default value: [timespan]::FromDays(30)
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientId
Application client ID used for app-only authentication.

```yaml
Type: Guid
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -KeyId
Graph credential key ID corresponding to Certificate, recorded during provisioning.

```yaml
Type: Guid
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Overlap
Minimum interval after activation before retiring the previous key. Defaults to one day.

```yaml
Type: TimeSpan
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 8
Default value: [timespan]::FromDays(1)
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
New dedicated local profile directory. Existing directories are never overwritten.

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

### -RenewBefore
Renew when this much certificate lifetime remains. Defaults to 14 days.

```yaml
Type: TimeSpan
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 6
Default value: [timespan]::FromDays(14)
Accept pipeline input: False
Accept wildcard characters: False
```

### -TenantId
Home tenant containing the application registration.

```yaml
Type: Guid
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `System.Management.Automation.PSCustomObject. Safe profile metadata without private keys or tokens.`

## RELATED LINKS

- None
