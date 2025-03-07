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
        # Prepare file information safely
        $Files = @()
        $FileLanguages = @()
        if ($Agreement.Files) {
            $Files = $Agreement.Files | Where-Object { $_ } | ForEach-Object { $_.DisplayName }
            $FileLanguages = $Agreement.Files | Where-Object { $_ } | ForEach-Object { $_.Language }
        } elseif ($Agreement.File) {
            if ($Agreement.File.DisplayName) {
                $Files = @($Agreement.File.DisplayName)
            }
            if ($Agreement.File.Language) {
                $FileLanguages = @($Agreement.File.Language)
            }
        }

        # Handle acceptance requirements safely
        $AcceptanceRequiredBy = @{
            AllUsers      = $false
            ExternalUsers = $false
            InternalUsers = $false
        }

        if ($Agreement.File.AcceptanceRequiredByValues) {
            $AcceptanceRequiredBy = @{
                AllUsers      = [bool]($Agreement.File.AcceptanceRequiredByValues.Values -contains 'All')
                ExternalUsers = [bool]($Agreement.File.AcceptanceRequiredByValues.Values -contains 'Guest')
                InternalUsers = [bool]($Agreement.File.AcceptanceRequiredByValues.Values -contains 'Member')
            }
        }

        # Calculate user scope for display
        $UserScope = @(
            if ($AcceptanceRequiredBy.AllUsers) { 'All Users' }
            if ($AcceptanceRequiredBy.ExternalUsers) { 'External' }
            if ($AcceptanceRequiredBy.InternalUsers) { 'Internal' }
        ) -join ', '

        # Create both a summary object and a detailed object for different display needs
        $SummaryObject = [PSCustomObject]@{
            DisplayName        = $Agreement.DisplayName
            Version           = $Agreement.Version
            AcceptanceRequired = [bool]$Agreement.IsAcceptanceRequired
            ViewingRequired   = [bool]$Agreement.IsViewingBeforeAcceptanceRequired
            Reacceptance      = $Agreement.UserReacceptRequiredFrequency
            Languages         = $FileLanguages -join ', '
            UserScope         = $UserScope
            Modified          = $Agreement.ModifiedDateTime
        }

        $DetailedObject = [PSCustomObject]@{
            Settings = [PSCustomObject]@{
                Id                     = $Agreement.Id
                Version               = $Agreement.Version
                Created               = $Agreement.CreatedDateTime
                Modified              = $Agreement.ModifiedDateTime
                ViewingRequired       = [bool]$Agreement.IsViewingBeforeAcceptanceRequired
                AcceptanceRequired    = [bool]$Agreement.IsAcceptanceRequired
                PerDeviceRequired     = [bool]$Agreement.IsPerDeviceAcceptanceRequired
                ReacceptanceFrequency = $Agreement.UserReacceptRequiredFrequency
                TermsExpiration       = $Agreement.TermsExpiration
            }
            Files = $(
                $Languages = $FileLanguages
                $FileNames = $Files
                0..([Math]::Max($Languages.Count, $FileNames.Count) - 1) | ForEach-Object {
                    [PSCustomObject]@{
                        FileName = if ($_ -lt $FileNames.Count) { $FileNames[$_] } else { 'N/A' }
                        Language = if ($_ -lt $Languages.Count) { $Languages[$_] } else { 'N/A' }
                    }
                }
            )
            AcceptanceRequiredBy = [PSCustomObject]$AcceptanceRequiredBy
        }

        [PSCustomObject]@{
            Summary  = $SummaryObject
            Detailed = $DetailedObject
        }
    }
}