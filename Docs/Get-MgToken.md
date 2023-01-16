---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---

# Get-MgToken

## SYNOPSIS
{{ Fill in the Synopsis }}

## SYNTAX

### Domain (Default)
```
Get-MgToken -ClientID <String> -ClientSecret <String> -Domain <String> [<CommonParameters>]
```

### DomainEncrypted
```
Get-MgToken -ClientID <String> -ClientSecretEncrypted <String> -Domain <String> [<CommonParameters>]
```

### TenantIDEncrypted
```
Get-MgToken -ClientID <String> -ClientSecretEncrypted <String> -TenantID <String> [<CommonParameters>]
```

### TenantID
```
Get-MgToken -ClientID <String> -ClientSecret <String> -TenantID <String> [<CommonParameters>]
```

## DESCRIPTION
{{ Fill in the Description }}

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -ClientID
{{ Fill ClientID Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases: ApplicationID

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientSecret
{{ Fill ClientSecret Description }}

```yaml
Type: String
Parameter Sets: Domain, TenantID
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientSecretEncrypted
{{ Fill ClientSecretEncrypted Description }}

```yaml
Type: String
Parameter Sets: DomainEncrypted, TenantIDEncrypted
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TenantID
{{ Fill TenantID Description }}

```yaml
Type: String
Parameter Sets: TenantIDEncrypted, TenantID
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Domain
{{ Fill Domain Description }}

```yaml
Type: String
Parameter Sets: Domain, DomainEncrypted
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.Object
## NOTES

## RELATED LINKS
