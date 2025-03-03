function Get-MyTermsOfUse {
    <#
    .SYNOPSIS
    Retrieves Terms of Use policies from Microsoft Graph.

    .DESCRIPTION
    Gets detailed information about Terms of Use policies configured in Azure AD/Entra ID,
    including their display names, acceptance requirements, and assigned groups.

    .EXAMPLE
    Get-MyTermsOfUse
    Returns all Terms of Use policies from Microsoft Graph.

    .NOTES
    This function requires the Microsoft.Graph.Identity.SignIns module and appropriate permissions.
    Typically requires Agreement.Read.All permission.
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose -Message "Get-MyTermsOfUse - Getting Terms of Use agreements"
        $Agreements = Get-MgAgreement -All -ErrorAction Stop
        Write-Verbose -Message "Get-MyTermsOfUse - Retrieved $($Agreements.Count) agreements"

        if (-not $Agreements) {
            Write-Verbose -Message "Get-MyTermsOfUse - No Terms of Use agreements found"
            return
        }
    } catch {
        Write-Warning -Message "Get-MyTermsOfUse - Failed to get Terms of Use agreements. Error: $($_.Exception.Message)"
        return
    }

    foreach ($Agreement in $Agreements) {
        [PSCustomObject]@{
            DisplayName           = $Agreement.DisplayName
            Id                    = $Agreement.Id
            IsViewingBeforeAcceptanceRequired = $Agreement.IsViewingBeforeAcceptanceRequired
            IsAcceptanceRequired  = $Agreement.IsAcceptanceRequired
            TermsExpiration      = $Agreement.TermsExpiration
            UserReacceptRequiredFrequency = $Agreement.UserReacceptRequiredFrequency
            CreatedDateTime      = $Agreement.CreatedDateTime
            ModifiedDateTime     = $Agreement.ModifiedDateTime
            Files                = $Agreement.Files.DisplayName
            FileLanguages        = $Agreement.Files.Language
            Version              = $Agreement.Version
            AcceptanceRequiredBy = @{
                AllUsers          = $Agreement.File.AcceptanceRequiredByValues.ContainsKey('All')
                ExternalUsers     = $Agreement.File.AcceptanceRequiredByValues.ContainsKey('Guest')
                InternalUsers     = $Agreement.File.AcceptanceRequiredByValues.ContainsKey('Member')
            }
        }
    }
}