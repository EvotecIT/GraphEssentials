---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyAppCertificateRotation
## SYNOPSIS
Reads safe renewal status or loads the active certificate for Connect-MgGraph.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyAppCertificateRotation [-Path] <string> [-AsCertificate] [<CommonParameters>]
```

## DESCRIPTION
Reads a profile protected for the current Windows account. Ordinary output contains identifiers,
public thumbprints, expiry and lifecycle state. AsCertificate explicitly loads a private credential
into this process; keep it alive for the SDK connection and dispose it after disconnecting.
No Graph connection, certificate-store import or credential write occurs.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyAppCertificateRotation -Path $profilePath
Inspects renewal and reconciliation status without exposing private credentials.
```


### EXAMPLE 2
```powershell
PS > $certificate = Get-MyAppCertificateRotation -Path $profilePath -AsCertificate
Connect-MgGraph -TenantId $tenantId -ClientId $clientId -Certificate $certificate -ContextScope Process -NoWelcome
Loads the enrolled credential for the script's normal Microsoft Graph authentication.
```


## PARAMETERS

### -AsCertificate
Returns the active X509Certificate2 with an ephemeral private key instead of status metadata.

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

### -Path
Local profile directory created by Register-MyAppCertificateRotation.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `System.Management.Automation.PSCustomObject, or System.Security.Cryptography.X509Certificates.X509Certificate2 with AsCertificate.`

## RELATED LINKS

- None
