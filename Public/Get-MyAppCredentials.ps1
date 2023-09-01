function Get-MyAppCredentials {
    [cmdletBinding()]
    param(
        [string] $ApplicationName,
        [int] $LessThanDaysToExpire,
        [int] $GreaterThanDaysToExpire,
        [switch] $Expired,
        [alias('DescriptionCredentials', 'ClientSecretName')][string] $DisplayNameCredentials,
        [Parameter(DontShow)][Array] $ApplicationList
    )
    if (-not $ApplicationList) {
        if ($ApplicationName) {
            $ApplicationList = Get-MgApplication -Filter "displayName eq '$ApplicationName'" -All -ConsistencyLevel eventual
        } else {
            $ApplicationList = Get-MgApplication -All
        }
    } else {
        $ApplicationList = foreach ($App in $ApplicationList) {
            if ($PSBoundParameters.ContainsKey('ApplicationName')) {
                if ($App.DisplayName -eq $ApplicationName) {
                    $App
                }
            } else {
                $App
            }
        }
    }
    $ApplicationsWithCredentials = foreach ($App in $ApplicationList) {
        if ($App.PasswordCredentials) {
            foreach ($Credentials in $App.PasswordCredentials) {
                if ($Credentials.EndDateTime -lt [DateTime]::Now) {
                    $IsExpired = $true
                } else {
                    $IsExpired = $false
                }
                if ($null -ne $Credentials.DisplayName) {
                    $DisplayName = $Credentials.DisplayName
                } elseif ($null -ne $Credentials.CustomKeyIdentifier) {
                    if ($Credentials.CustomKeyIdentifier[0] -eq 255 -and $Credentials.CustomKeyIdentifier[1] -eq 254 -and $Credentials.CustomKeyIdentifier[0] -ne 0 -and $Credentials.CustomKeyIdentifier[0] -ne 0) {
                        $DisplayName = [System.Text.Encoding]::Unicode.GetString($Credentials.CustomKeyIdentifier)
                    } elseif ($Credentials.CustomKeyIdentifier[0] -eq 255 -and $Credentials.CustomKeyIdentifier[1] -eq 254 -and $Credentials.CustomKeyIdentifier[0] -eq 0 -and $Credentials.CustomKeyIdentifier[0] -eq 0) {
                        $DisplayName = [System.Text.Encoding]::UTF32.GetString($Credentials.CustomKeyIdentifier)
                    } elseif ($Credentials.CustomKeyIdentifier[1] -eq 0 -and $Credentials.CustomKeyIdentifier[3] -eq 0) {
                        $DisplayName = [System.Text.Encoding]::Unicode.GetString($Credentials.CustomKeyIdentifier)
                    } else {
                        $DisplayName = [System.Text.Encoding]::UTF8.GetString($Credentials.CustomKeyIdentifier)
                    }
                } else {
                    $DisplayName = $Null
                }

                $Creds = [PSCustomObject] @{
                    ObjectId        = $App.Id
                    ApplicationName = $App.DisplayName
                    Type            = 'Password'
                    ClientID        = $App.AppId
                    CreatedDate     = $App.CreatedDateTime
                    KeyDisplayName     = $DisplayName
                    KeyId           = $Credentials.KeyId
                    #ClientSecret        = $Credentials.SecretTex
                    Hint            = $Credentials.Hint
                    Expired         = $IsExpired
                    DaysToExpire    = ($Credentials.EndDateTime - [DateTime]::Now).Days
                    StartDateTime   = $Credentials.StartDateTime
                    EndDateTime     = $Credentials.EndDateTime
                    #CustomKeyIdentifier = $Credentials.CustomKeyIdentifier
                }
                if ($PSBoundParameters.ContainsKey('DisplayNameCredentials')) {
                    if ($Creds.DisplayName -notlike $DisplayNameCredentials) {
                        continue
                    }
                }
                if ($PSBoundParameters.ContainsKey('LessThanDaysToExpire')) {
                    if ($LessThanDaysToExpire -lt $Creds.DaysToExpire) {
                        continue
                    }
                } elseif ($PSBoundParameters.ContainsKey('Expired')) {
                    if ($Creds.Expired -eq $false) {
                        continue
                    }
                } elseif ($PSBoundParameters.ContainsKey('GreaterThanDaysToExpire')) {
                    if ($GreaterThanDaysToExpire -gt $Creds.DaysToExpire) {
                        continue
                    }
                }
                $Creds

            }
        }
        if ($App.KeyCredentials) {
            foreach ($Credentials in $App.KeyCredentials) {
                if ($Credentials.EndDateTime -lt [DateTime]::Now) {
                    $IsExpired = $true
                } else {
                    $IsExpired = $false
                }
                if ($null -ne $Credentials.DisplayName) {
                    $DisplayName = $Credentials.DisplayName
                } elseif ($null -ne $Credentials.CustomKeyIdentifier) {
                    if ($Credentials.CustomKeyIdentifier[0] -eq 255 -and $Credentials.CustomKeyIdentifier[1] -eq 254 -and $Credentials.CustomKeyIdentifier[0] -ne 0 -and $Credentials.CustomKeyIdentifier[0] -ne 0) {
                        $DisplayName = [System.Text.Encoding]::Unicode.GetString($Credentials.CustomKeyIdentifier)
                    } elseif ($Credentials.CustomKeyIdentifier[0] -eq 255 -and $Credentials.CustomKeyIdentifier[1] -eq 254 -and $Credentials.CustomKeyIdentifier[0] -eq 0 -and $Credentials.CustomKeyIdentifier[0] -eq 0) {
                        $DisplayName = [System.Text.Encoding]::UTF32.GetString($Credentials.CustomKeyIdentifier)
                    } elseif ($Credentials.CustomKeyIdentifier[1] -eq 0 -and $Credentials.CustomKeyIdentifier[3] -eq 0) {
                        $DisplayName = [System.Text.Encoding]::Unicode.GetString($Credentials.CustomKeyIdentifier)
                    } else {
                        $DisplayName = [System.Text.Encoding]::UTF8.GetString($Credentials.CustomKeyIdentifier)
                    }
                } else {
                    $DisplayName = $Null
                }

                $Creds = [PSCustomObject] @{
                    ObjectId        = $App.Id
                    ApplicationName = $App.DisplayName
                    Type            = 'Certificate'
                    ClientID        = $App.AppId
                    CreatedDate     = $App.CreatedDateTime
                    KeyDisplayName     = $DisplayName
                    KeyId           = $Credentials.KeyId
                    #ClientSecret        = $Credentials.SecretTex
                    Hint            = $Credentials.Hint
                    Expired         = $IsExpired
                    DaysToExpire    = ($Credentials.EndDateTime - [DateTime]::Now).Days
                    StartDateTime   = $Credentials.StartDateTime
                    EndDateTime     = $Credentials.EndDateTime
                    #CustomKeyIdentifier = $Credentials.CustomKeyIdentifier
                }
                if ($PSBoundParameters.ContainsKey('DisplayNameCredentials')) {
                    if ($Creds.KeyDisplayName -notlike $DisplayNameCredentials) {
                        continue
                    }
                }
                if ($PSBoundParameters.ContainsKey('LessThanDaysToExpire')) {
                    if ($LessThanDaysToExpire -lt $Creds.DaysToExpire) {
                        continue
                    }
                } elseif ($PSBoundParameters.ContainsKey('Expired')) {
                    if ($Creds.Expired -eq $false) {
                        continue
                    }
                } elseif ($PSBoundParameters.ContainsKey('GreaterThanDaysToExpire')) {
                    if ($GreaterThanDaysToExpire -gt $Creds.DaysToExpire) {
                        continue
                    }
                }
                $Creds

            }
        }
    }
    $ApplicationsWithCredentials
}