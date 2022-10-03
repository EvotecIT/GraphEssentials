function Get-MyAppCredentials {
    [cmdletBinding()]
    param(
        [int] $LessThanDaysToExpire,
        [switch] $Expired,
        [Parameter(DontShow)][Array] $Application
    )

    if (-not $Application) {
        $Application = Get-MgApplication
    }
    $ApplicationsWithCredentials = foreach ($App in $Application) {
        if ($App.PasswordCredentials) {
            foreach ($Credentials in $App.PasswordCredentials) {
                if ($Credentials.EndDateTime -lt [DateTime]::Now) {
                    $Expired = $true
                } else {
                    $Expired = $false
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
                    Id                  = $App.Id
                    ApplicationID       = $App.AppId
                    ApplicationName     = $App.DisplayName
                    CreatedDate         = $App.CreatedDateTime
                    CredentialName      = $DisplayName
                    Expired             = $Expired
                    DaysToExpire        = ($Credentials.EndDateTime - [DateTime]::Now).Days
                    StartDateTime       = $Credentials.StartDateTime
                    EndDateTime         = $Credentials.EndDateTime
                    Hint                = $Credentials.Hint
                    KeyId               = $Credentials.KeyId
                    SecretText          = $Credentials.SecretTex
                    CustomKeyIdentifier = $Credentials.CustomKeyIdentifier
                }
                if ($PSBoundParameters.ContainsKey('LessThanDaysToExpire')) {
                    if ($LessThanDaysToExpire -ge $Creds.DaysToExpire) {
                        $Creds
                    }
                } elseif ($PSBoundParameters.ContainsKey('Expired')) {
                    $Creds
                } else {
                    $Creds
                }
            }
        }
    }
    $ApplicationsWithCredentials
}