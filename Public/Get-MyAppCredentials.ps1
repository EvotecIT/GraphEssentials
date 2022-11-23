function Get-MyAppCredentials {
    [cmdletBinding()]
    param(
        [string] $ApplicationName,
        [int] $LessThanDaysToExpire,
        [int] $GreaterThanDaysToExpire,
        [switch] $Expired,
        [alias('DescriptionCredentials', 'ClientSecretName')][string] $DisplayNameCredentials,
        [Parameter(DontShow)][Array] $Application
    )
    if (-not $Application) {
        if ($ApplicationName) {
            $Application = Get-MgApplication -Filter "displayName eq '$ApplicationName'" -All -ConsistencyLevel eventual
        } else {
            $Application = Get-MgApplication -All
        }
    } else {
        $Application = foreach ($App in $Application) {
            if ($App.DisplayName -eq $ApplicationName) {
                $App
            }
        }
    }
    $ApplicationsWithCredentials = foreach ($App in $Application) {
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
                    ObjectId         = $App.Id
                    ApplicationName  = $App.DisplayName
                    ClientID         = $App.AppId
                    CreatedDate      = $App.CreatedDateTime
                    ClientSecretName = $DisplayName
                    ClientSecretId   = $Credentials.KeyId
                    #ClientSecret        = $Credentials.SecretTex
                    ClientSecretHint = $Credentials.Hint
                    Expired          = $IsExpired
                    DaysToExpire     = ($Credentials.EndDateTime - [DateTime]::Now).Days
                    StartDateTime    = $Credentials.StartDateTime
                    EndDateTime      = $Credentials.EndDateTime
                    #CustomKeyIdentifier = $Credentials.CustomKeyIdentifier
                }
                if ($PSBoundParameters.ContainsKey('DisplayNameCredentials')) {
                    if ($Creds.ClientSecretName -notlike $DisplayNameCredentials) {
                        continue
                    }
                }
                if ($PSBoundParameters.ContainsKey('LessThanDaysToExpire')) {
                    if ($LessThanDaysToExpire -ge $Creds.DaysToExpire) {
                        #$Creds
                    } else {
                        continue
                    }
                } elseif ($PSBoundParameters.ContainsKey('Expired')) {
                    if ($Creds.Expired -eq $true) {

                    } else {
                        continue
                    }
                } elseif ($PSBoundParameters.ContainsKey('GreaterThanDaysToExpire')) {
                    if ($GreaterThanDaysToExpire -le $Creds.DaysToExpire) {
                        #$Creds
                    } else {
                        continue
                    }
                }
                $Creds

            }
        }
    }
    $ApplicationsWithCredentials
}