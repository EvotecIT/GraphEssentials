function Get-MyAuthenticationContext {
    <#
    .SYNOPSIS
    Retrieves Authentication Context configurations from Microsoft Graph.

    .DESCRIPTION
    Gets detailed information about Authentication Context configurations in Azure AD/Entra ID,
    which define specific authentication requirements that can be applied to sensitive applications.

    .EXAMPLE
    Get-MyAuthenticationContext
    Returns all authentication context configurations.

    .NOTES
    This function requires the Microsoft.Graph.Identity.SignIns module and appropriate permissions.
    Typically requires Policy.Read.All permission.
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose -Message "Get-MyAuthenticationContext - Getting authentication context configurations"
        $AuthContexts = Get-MgIdentityConditionalAccessAuthenticationContextClassReference -All -ErrorAction Stop
        Write-Verbose -Message "Get-MyAuthenticationContext - Retrieved $($AuthContexts.Count) authentication contexts"

        if (-not $AuthContexts) {
            Write-Verbose -Message "Get-MyAuthenticationContext - No authentication contexts found"
            return
        }

        foreach ($Context in $AuthContexts) {
            [PSCustomObject]@{
                DisplayName                     = $Context.DisplayName
                Id                              = $Context.Id
                Description                     = $Context.Description
                IsAvailable                     = $Context.IsAvailable
                RequireExternalTenantsMfaStatus = $Context.RequireExternalTenantsMfaStatus
                CreatedDateTime                 = $Context.CreatedDateTime
                ModifiedDateTime                = $Context.ModifiedDateTime
            }
        }
    } catch {
        Write-Warning -Message "Get-MyAuthenticationContext - Failed to get authentication contexts. Error: $($_.Exception.Message)"
        return
    }
}