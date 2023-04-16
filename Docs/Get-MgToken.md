---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---

# Get-MgToken

## SYNOPSIS
Provides a way to get a token for Microsoft Graph API to be used with Connect-MGGraph

## SYNTAX

### Domain (Default)
```
Get-MgToken -ClientID <String> -ClientSecret <String> -Domain <String> [-Proxy <String>]
 [-ProxyCredential <PSCredential>] [-ProxyUseDefaultCredentials] [<CommonParameters>]
```

### DomainEncrypted
```
Get-MgToken -ClientID <String> -ClientSecretEncrypted <String> -Domain <String> [-Proxy <String>]
 [-ProxyCredential <PSCredential>] [-ProxyUseDefaultCredentials] [<CommonParameters>]
```

### TenantIDEncrypted
```
Get-MgToken -ClientID <String> -ClientSecretEncrypted <String> -TenantID <String> [-Proxy <String>]
 [-ProxyCredential <PSCredential>] [-ProxyUseDefaultCredentials] [<CommonParameters>]
```

### TenantID
```
Get-MgToken -ClientID <String> -ClientSecret <String> -TenantID <String> [-Proxy <String>]
 [-ProxyCredential <PSCredential>] [-ProxyUseDefaultCredentials] [<CommonParameters>]
```

## DESCRIPTION
Provides a way to get a token for Microsoft Graph API to be used with Connect-MGGraph

## EXAMPLES

### EXAMPLE 1
```
Get-MgToken -ClientID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -ClientSecret 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' -TenantID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
```

### EXAMPLE 2
```
Get-MgToken -ClientID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -ClientSecret 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' -Domain 'contoso.com'
```

### EXAMPLE 3
```
$ClientSecretEncrypted = 'ClientSecretToEncrypt' | ConvertTo-SecureString -AsPlainText | ConvertFrom-SecureString
```

$AccessToken = Get-MgToken -Domain 'evotec.pl' -ClientID 'ClientID' -ClientSecretEncrypted $ClientSecretEncrypted
Connect-MgGraph -AccessToken $AccessToken

## PARAMETERS

### -ClientID
Provide the Application ID of the App Registration

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
Provide the Client Secret of the App Registration

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
Provide the Tenant ID of the App Registration

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
Provide the Domain of the tenant where the App is registred

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

### -Proxy
{{ Fill Proxy Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProxyCredential
{{ Fill ProxyCredential Description }}

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProxyUseDefaultCredentials
{{ Fill ProxyUseDefaultCredentials Description }}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
General notes

## RELATED LINKS
