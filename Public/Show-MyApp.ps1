function Show-MyApp {
    <#
    .SYNOPSIS
    Generates an HTML report for Azure AD applications, their credentials, permissions, and activity.

    .DESCRIPTION
    Creates a comprehensive HTML report displaying information about Azure AD/Entra applications,
    including owners, credential details, source (first/third party), permissions (delegated/application),
    sign-in activity, and credential expiry. Includes summary statistics.

    .PARAMETER FilePath
    The path where the HTML report will be saved.

    .PARAMETER Online
    If specified, opens the HTML report in the default browser after generation.

    .PARAMETER ShowHTML
    If specified, displays the HTML content in the PowerShell console after generation.

    .PARAMETER ApplicationType
    Specifies the type of applications to include in the report.

    .EXAMPLE
    Show-MyApp -FilePath "C:\Reports\Applications.html"
    Generates an applications report and saves it to the specified path.

    .EXAMPLE
    Show-MyApp -FilePath "C:\Reports\Applications.html" -Online
    Generates an applications report, saves it to the specified path, and opens it in the default browser.

    .NOTES
    This function requires the PSWriteHTML module and the enhanced Get-MyApp function.
    Ensure appropriate Microsoft Graph permissions are granted for Get-MyApp (Application.Read.All, AuditLog.Read.All, etc.).
    #>
    [cmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML,
        [ValidateSet('All', 'AppRegistrations', 'EnterpriseApps', 'MicrosoftApps', 'ManagedIdentities')]
        [string]$ApplicationType = 'All',
        [switch] $IncludeRealtimeSignIns,
        [switch] $IncludeDetailedSignInLogs,
        [switch] $IncludeFederated,
        [ValidateSet('Full','Light','Minimal')][string] $DetailLevel = 'Full'
    )

    $Script:Reporting = [ordered] @{}
    $Script:Reporting['Version'] = Get-GitHubVersion -Cmdlet 'Invoke-MyGraphEssentials' -RepositoryOwner 'evotecit' -RepositoryName 'GraphEssentials'

    # --- Get Enhanced Application Data ---
    Write-Verbose "Show-MyApp: Getting application data using Get-MyApp (ApplicationType: $ApplicationType)..."
    $Applications = Get-MyApp -ApplicationType $ApplicationType -IncludeRealtimeSignIns:$IncludeRealtimeSignIns.IsPresent -IncludeDetailedSignInLogs:$IncludeDetailedSignInLogs.IsPresent -DetailLevel $DetailLevel
    if (-not $Applications) {
        Write-Warning "Show-MyApp: No application data received from Get-MyApp. Report will be incomplete."
        # Optionally exit or continue with an empty report
        # return
    }

    # --- Get Detailed Credentials Data (for second table) ---
    # Get-MyApp now includes summary info, but we still need details for the expiry table
    Write-Verbose "Show-MyApp: Getting detailed credentials using Get-MyAppCredentials..."
    $ApplicationsPassword = Get-MyAppCredentials -IncludeFederated:$IncludeFederated.IsPresent # Fetch details for all apps for the second table
    if (-not $ApplicationsPassword) {
        Write-Warning "Show-MyApp: No detailed credential data received from Get-MyAppCredentials. Credentials table will be empty."
    }

    New-HTML -TitleText "Entra Application Report" {
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor '#0078d4' -RemoveShadow
        New-HTMLPanelStyle -BorderRadius 0px
        New-HTMLTableOption -DataStore JavaScript -BoolAsString -ArrayJoinString ', ' -ArrayJoin

        New-HTMLHeader {
            New-HTMLSection -Invisible {
                New-HTMLSection {
                    New-HTMLText -Text "Report generated on $(Get-Date)" -Color Blue
                } -JustifyContent flex-start -Invisible
                New-HTMLSection {
                    New-HTMLText -Text "GraphEssentials - $($Script:Reporting['Version'])" -Color Blue
                } -JustifyContent flex-end -Invisible
            }
        }

        Add-AppsOverviewContent -Applications $Applications -Credentials $ApplicationsPassword -Version $Script:Reporting['Version']
    } -ShowHTML:$ShowHTML.IsPresent -FilePath $FilePath -Online:$Online.IsPresent
}
