function Get-MyDefenderSecureScoreProfile {
    <#
    .SYNOPSIS
    Retrieves Microsoft Defender secure score control profiles.

    .DESCRIPTION
    Gets detailed information about Microsoft Defender secure score control profiles from the Microsoft Graph Security API.
    This provides information about each security control that contributes to the overall secure score.

    .PARAMETER AsHashtable
    When specified, returns the results as a hashtable with control IDs as keys for easier lookup.

    .EXAMPLE
    Get-MyDefenderSecureScoreProfile
    Returns the Microsoft Defender secure score control profiles as an array of objects.

    .EXAMPLE
    Get-MyDefenderSecureScoreProfile -AsHashtable
    Returns the Microsoft Defender secure score control profiles as a hashtable keyed by control ID.

    .NOTES
    This function requires the Microsoft.Graph.Beta.Security module and appropriate permissions.
    #>
    [cmdletbinding()]
    param(
        [switch] $AsHashtable
    )
    Write-Verbose -Message 'Get-MyDefenderSecureScoreProfile - Getting Secure Score Profile'
    $ScoreList = Get-MgBetaSecuritySecureScoreControlProfile -All
    $List = foreach ($Score in $ScoreList) {
        [PSCustomObject] @{
            Title                = $Score.Title                  #: Ensure Administrative accounts are separate and cloud-only
            Tier                 = $Score.Tier                   #: Core
            ActionType           = $Score.ActionType             #: Config
            Threats              = $Score.Threats | ForEach-Object { $_ }              #: {Account breach}
            Service              = $Score.Service                #: AzureAD
            ActionUrl            = $Score.ActionUrl              #: https://learn.microsoft.com/en-us/microsoft-365/admin/add-users/add-users?view=o365-worldwide
            AzureTenantId        = $Score.AzureTenantId          #: ceb371f6-8745-4876-a040-69f2d10a9d1a
            #ComplianceInformation = $Score.ComplianceInformation  #: {}
            ControlCategory      = $Score.ControlCategory        #: Apps
            #ControlStateUpdates   = $Score.ControlStateUpdates    #: {Microsoft.Graph.Beta.PowerShell.Models.MicrosoftGraphSecureScoreControlStateUpdate}
            Deprecated           = $Score.Deprecated             #: False
            Id                   = $Score.Id                     #: aad_admin_accounts_separate_unassigned_cloud_only
            ImplementationCost   = $Score.ImplementationCost     #: Unknown
            LastModifiedDateTime = $Score.LastModifiedDateTime   #:
            MaxScore             = $Score.MaxScore               #: 3
            Rank                 = $Score.Rank                   #: 10
            Remediation          = $Score.Remediation            #:  <p>1. Navigate to Microsoft 365 admin center <br />2. Click to expand Users select Active users.<br />3. Sort by the Licenses column.<br />4. For each user account in an administrative role verify the following:<br /> The account is Cloud only (not synced)<br /> The account is assigned a license that is not associated with applications i.e. (Microsoft Entra ID P1, Microsoft Entra ID
            RemediationImpact    = $Score.RemediationImpact      #: Administrative users will have to switch accounts and utilizing login/logout functionality when performing Administrative tasks, as well as not benefiting from SSO.

            UserImpact           = $Score.UserImpact             #: Unknown
            VendorInformation    = $Score.VendorInformation.Vendor      #: Microsoft.Graph.Beta.PowerShell.Models.MicrosoftGraphSecurityVendorInformation
            #AdditionalProperties  = $Score.AdditionalProperties   #: {}
        }
        if ($Score.ComplianceInformation.Count -gt 0) {
            Write-Warning -Message "Get-MyDefenderSecureScoreProfile - ComplianceInformation found in control '$($Score.Title)'. Please update the script to include this property."
        }
        #if ($Score.ControlStateUpdates.Count -gt 0) {
        #    Write-Warning -Message "Get-MyDefenderSecureScoreProfile - ControlStateUpdates found in control '$($Score.Title)'. Please update the script to include this property."
        #}
        if ($Score.AdditionalProperties.Count -gt 0) {
            Write-Warning -Message "Get-MyDefenderSecureScoreProfile - AdditionalProperties found in control '$($Score.Title)'. Please update the script to include this property."
        }
    }
    $OutputData = [ordered] @{}
    if ($AsHashtable) {
        foreach ($Score in $List) {
            $OutputData[$Score.Id] = $Score
        }
        $OutputData
    } else {
        $List
    }
}