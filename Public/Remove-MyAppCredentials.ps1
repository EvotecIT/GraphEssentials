function Remove-MyAppCredentials {
    <#
    .SYNOPSIS
    Removes credentials from an Azure AD application.

    .DESCRIPTION
    Removes client secret credentials from Azure AD/Entra applications based on various filtering criteria.
    This function can remove credentials from one or multiple applications at once.

    .PARAMETER ApplicationName
    The name of the application to remove credentials from. If not provided, checks all applications.

    .PARAMETER LessThanDaysToExpire
    When specified, removes only credentials that expire in less than the specified number of days.

    .PARAMETER GreaterThanDaysToExpire
    When specified, removes only credentials that expire in more than the specified number of days.

    .PARAMETER Expired
    When specified, removes only already expired credentials.

    .PARAMETER DisplayNameCredentials
    When specified, removes only credentials with the specified display name or description.

    .PARAMETER WhatIf
    Shows what would happen if the cmdlet runs. The cmdlet doesn't run.

    .PARAMETER Confirm
    Prompts you for confirmation before running the cmdlet.

    .EXAMPLE
    Remove-MyAppCredentials -ApplicationName "MyAPI" -Expired
    Removes all expired credentials from the application named "MyAPI".

    .EXAMPLE
    Remove-MyAppCredentials -LessThanDaysToExpire 30
    Removes credentials from all applications that expire in less than 30 days.

    .EXAMPLE
    Remove-MyAppCredentials -DisplayNameCredentials "Old API Access"
    Removes all credentials with the display name "Old API Access" from all applications.

    .NOTES
    This function requires the Microsoft.Graph.Applications module and appropriate permissions.
    Requires Application.ReadWrite.All permissions to manage application credentials.
    #>
    [cmdletBinding(SupportsShouldProcess)]
    param(
        [string] $ApplicationName,
        [int] $LessThanDaysToExpire,
        [int] $GreaterThanDaysToExpire,
        [switch] $Expired,
        [alias('DescriptionCredentials', 'ClientSecretName')][string] $DisplayNameCredentials
    )

    $ApplicationsWithCredentials = Get-MyAppCredentials -ApplicationName $ApplicationName -LessThanDaysToExpire $LessThanDaysToExpire -GreaterThanDaysToExpire $GreaterThanDaysToExpire -Expired:$Expired.IsPresent -DisplayNameCredentials $DisplayNameCredentials

    if ($ApplicationsWithCredentials) {
        $GroupedByObjectId = $ApplicationsWithCredentials | Group-Object -Property ObjectId

        foreach ($Group in $GroupedByObjectId) {
            $Application = Get-MgApplication -ApplicationId $Group.Name
            foreach ($Credential in $Group.Group) {
                if ($PSCmdlet.ShouldProcess("$($Credential.ApplicationName) ID:$($Credential.KeyId)", "Remove Credential")) {
                    try {
                        if ($Credential.Type -eq 'Password') {
                            Remove-MgApplicationPassword -ApplicationId $Group.Name -KeyId $Credential.KeyId -ErrorAction Stop
                            [PSCustomObject] @{
                                Status          = $true
                                ApplicationName = $Application.DisplayName
                                ApplicationId   = $Application.AppId
                                ObjectId        = $Application.Id
                                KeyId           = $Credential.KeyId
                                KeyDisplayName  = $Credential.KeyDisplayName
                                Type            = $Credential.Type
                                Information     = "Removed credential $($Credential.KeyId) from $($Application.DisplayName)"
                            }
                        } elseif ($Credential.Type -eq 'Certificate') {
                            Remove-MgApplicationKey -ApplicationId $Group.Name -KeyId $Credential.KeyId -ErrorAction Stop
                            [PSCustomObject] @{
                                Status          = $true
                                ApplicationName = $Application.DisplayName
                                ApplicationId   = $Application.AppId
                                ObjectId        = $Application.Id
                                KeyId           = $Credential.KeyId
                                KeyDisplayName  = $Credential.KeyDisplayName
                                Type            = $Credential.Type
                                Information     = "Removed certificate $($Credential.KeyId) from $($Application.DisplayName)"
                            }
                        } else {
                            Write-Warning -Message "Remove-MyAppCredentials - Unknown credential type $($Credential.Type) for $($Application.DisplayName) with Key ID $($Credential.KeyId)"
                            [PSCustomObject] @{
                                Status          = $false
                                ApplicationName = $Application.DisplayName
                                ApplicationId   = $Application.AppId
                                ObjectId        = $Application.Id
                                KeyId           = $Credential.KeyId
                                KeyDisplayName  = $Credential.KeyDisplayName
                                Type            = $Credential.Type
                                Information     = "Unknown credential type $($Credential.Type) for $($Application.DisplayName) with Key ID $($Credential.KeyId)"
                            }
                        }
                    } catch {
                        [PSCustomObject] @{
                            Status          = $false
                            ApplicationName = $Application.DisplayName
                            ApplicationId   = $Application.AppId
                            ObjectId        = $Application.Id
                            KeyId           = $Credential.KeyId
                            KeyDisplayName  = $Credential.KeyDisplayName
                            Type            = $Credential.Type
                            Information     = "Failed to remove $($Credential.Type) $($Credential.KeyId) from $($Application.DisplayName). Error: $($_.Exception.Message)"
                        }
                    }
                }
            }
        }
    } else {
        Write-Verbose -Message "Remove-MyAppCredentials - No credentials found matching the specified criteria."
    }
}