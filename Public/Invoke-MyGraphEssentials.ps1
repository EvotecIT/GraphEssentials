function Invoke-MyGraphEssentials {
    <#
    .SYNOPSIS
    Generates comprehensive reports for various Microsoft Graph resources.

    .DESCRIPTION
    Creates HTML reports for Microsoft Graph resources such as apps, devices, roles, and users.
    Reports can be customized and filtered based on the specified types and can be output as a single
    report or split into multiple reports.

    .PARAMETER FilePath
    The path where the HTML report will be saved. If not provided, a temporary file path will be used.

    .PARAMETER Type
    Array of report types to generate. Valid values include DevicesIntune, Roles, RolesUsers, Apps, etc.

    .PARAMETER PassThru
    When specified, returns the reporting data object after generating reports.

    .PARAMETER HideHTML
    When specified, doesn't display the HTML report in the default browser.

    .PARAMETER HideSteps
    When specified, hides the step-by-step details in the console output.

    .PARAMETER ShowError
    When specified, shows error details in the console output.

    .PARAMETER ShowWarning
    When specified, shows warning messages in the console output.

    .PARAMETER Online
    When specified, opens the generated report in the default web browser.

    .PARAMETER SplitReports
    When specified, generates separate HTML files for each report type instead of a combined report.

    .PARAMETER AppsDetailLevel
    Controls how much data Apps collection gathers:
    - Full    : current behaviour (delegated grants, owners, comprehensive activity)
    - Light   : skips delegated permission grants and comprehensive activity (keeps owners)
    - Minimal : skips delegated permission grants, owners and comprehensive activity (expiry-only)

    .PARAMETER AppsApplicationType
    Filters which Service Principals are processed by Get-MyApp:
    - All (default), AppRegistrations (First Party), EnterpriseApps (Third Party), MicrosoftApps, ManagedIdentities

    .PARAMETER IncludeOwnerDiagnostics
    When set, AppsOverview renders extra owner-diagnostics columns (OwnerResolvedId/Email/Status, etc.).
    Defaults to off to keep the generic report lean.

    .EXAMPLE
    Invoke-MyGraphEssentials -Type DevicesIntune, Roles, RolesUsers -FilePath "C:\Reports\GraphReport.html" -Online
    Generates a combined report for devices, roles, and role users, and opens it in the default web browser.

    .EXAMPLE
    Invoke-MyGraphEssentials -Type Apps, AppsCredentials -FilePath "C:\Reports\Apps.html" -SplitReports
    Generates separate reports for Apps and AppsCredentials in individual HTML files.

    .NOTES
    This function requires appropriate Microsoft Graph module and permissions to access the requested resources.
    Different report types may require different permission scopes in Microsoft Graph.
    #>
    [cmdletBinding()]
    param(
        [string] $FilePath,
        [Parameter(Position = 0)][string[]] $Type,
        [switch] $PassThru,
        [switch] $HideHTML,
        [switch] $HideSteps,
        [switch] $ShowError,
        [switch] $ShowWarning,
        [switch] $Online,
        [switch] $SplitReports,
        [scriptblock] $PostProcess,
        [ValidateSet('Full','Light','Minimal')][string] $AppsDetailLevel = 'Full',
        [ValidateSet('All','AppRegistrations','EnterpriseApps','MicrosoftApps','ManagedIdentities')][string] $AppsApplicationType = 'All',
        [switch] $IncludeOwnerDiagnostics
    )
    Reset-GraphEssentials

    # Persist Apps detail preference for configuration execution
    $Script:GraphEssentialsAppsDetailLevel = $AppsDetailLevel
    $Script:GraphEssentialsAppsApplicationType = $AppsApplicationType
    $Script:GraphEssentialsIncludeOwnerDiagnostics = $IncludeOwnerDiagnostics.IsPresent

    #$Script:AllUsers = [ordered] @{}
    $Script:Cache = [ordered] @{}
    $Script:Reporting = [ordered] @{}
    $Script:Reporting['Version'] = Get-GitHubVersion -Cmdlet 'Invoke-MyGraphEssentials' -RepositoryOwner 'evotecit' -RepositoryName 'GraphEssentials'
    $Script:Reporting['Settings'] = @{
        ShowError   = $ShowError.IsPresent
        ShowWarning = $ShowWarning.IsPresent
        HideSteps   = $HideSteps.IsPresent
    }

    Write-Color '[i]', "[GraphEssentials] ", 'Version', ' [Informative] ', $Script:Reporting['Version'] -Color Yellow, DarkGray, Yellow, DarkGray, Magenta

    # Verify requested types are supported
    $Supported = [System.Collections.Generic.List[string]]::new()
    [Array] $NotSupported = foreach ($T in $Type) {
        if ($T -notin $Script:GraphEssentialsConfiguration.Keys ) {
            $T
        } else {
            $Supported.Add($T)
        }
    }
    if ($Supported) {
        Write-Color '[i]', "[GraphEssentials] ", 'Supported types', ' [Informative] ', "Chosen by user: ", ($Supported -join ', ') -Color Yellow, DarkGray, Yellow, DarkGray, Yellow, Magenta
    }
    if ($NotSupported) {
        Write-Color '[i]', "[GraphEssentials] ", 'Not supported types', ' [Informative] ', "Following types are not supported: ", ($NotSupported -join ', ') -Color Yellow, DarkGray, Yellow, DarkGray, Yellow, Magenta
        Write-Color '[i]', "[GraphEssentials] ", 'Not supported types', ' [Informative] ', "Please use one/multiple from the list: ", ($Script:GraphEssentialsConfiguration.Keys -join ', ') -Color Yellow, DarkGray, Yellow, DarkGray, Yellow, Magenta
        return
    }

    if ($FilePath) {
        $Directory = Split-Path -Path $FilePath -Parent
        if (-not (Test-Path -Path $Directory)) {
            Write-Color '[i]', "[GraphEssentials] ", 'Creating directory', ' [Informative] ', $Directory -Color Yellow, DarkGray, Yellow, DarkGray
            New-Item -Path $Directory -ItemType Directory -Force
        }
        if ($FilePath -notlike '*.html') {
            Write-Color '[i]', "[GraphEssentials] ", 'Invalid file path', ' [Error] ', "File path must end with .html" -Color Yellow, DarkGray, Yellow, DarkGray, Red
            return
        }
    }

    # Lets make sure we only enable those types which are requestd by user
    if ($Type) {
        foreach ($T in $Script:GraphEssentialsConfiguration.Keys) {
            $Script:GraphEssentialsConfiguration[$T].Enabled = $false
        }
        # Lets enable all requested ones
        foreach ($T in $Type) {
            $Script:GraphEssentialsConfiguration[$T].Enabled = $true
        }
    }

    # Build data
    foreach ($T in $Script:GraphEssentialsConfiguration.Keys) {
        if ($Script:GraphEssentialsConfiguration[$T].Enabled -eq $true) {
            $Script:Reporting[$T] = [ordered] @{
                Name              = $Script:GraphEssentialsConfiguration[$T].Name
                ActionRequired    = $null
                Data              = $null
                Exclusions        = $null
                WarningsAndErrors = $null
                Time              = $null
                Summary           = $null
                Variables         = Copy-Dictionary -Dictionary $Script:GraphEssentialsConfiguration[$T]['Variables']
            }
            if ($Exclusions) {
                if ($Exclusions -is [scriptblock]) {
                    $Script:Reporting[$T]['ExclusionsCode'] = $Exclusions
                }
                if ($Exclusions -is [Array]) {
                    $Script:Reporting[$T]['Exclusions'] = $Exclusions
                }
            }

            $TimeLogGraphEssentials = Start-TimeLog
            Write-Color -Text '[i]', '[Start] ', $($Script:GraphEssentialsConfiguration[$T]['Name']) -Color Yellow, DarkGray, Yellow
            $OutputCommand = Invoke-Command -ScriptBlock $Script:GraphEssentialsConfiguration[$T]['Execute'] -WarningVariable CommandWarnings -ErrorVariable CommandErrors #-ArgumentList $Forest, $ExcludeDomains, $IncludeDomains
            if ($OutputCommand -is [System.Collections.IDictionary]) {
                # in some cases the return will be wrapped in Hashtable/orderedDictionary and we need to handle this without an array
                $Script:Reporting[$T]['Data'] = $OutputCommand
            } else {
                # since sometimes it can be 0 or 1 objects being returned we force it being an array
                $Script:Reporting[$T]['Data'] = [Array] $OutputCommand
            }
            Invoke-Command -ScriptBlock $Script:GraphEssentialsConfiguration[$T]['Processing']
            $Script:Reporting[$T]['WarningsAndErrors'] = @(
                if ($ShowWarning) {
                    foreach ($War in $CommandWarnings) {
                        [PSCustomObject] @{
                            Type       = 'Warning'
                            Comment    = $War
                            Reason     = ''
                            TargetName = ''
                        }
                    }
                }
                if ($ShowError) {
                    foreach ($Err in $CommandErrors) {
                        [PSCustomObject] @{
                            Type       = 'Error'
                            Comment    = $Err
                            Reason     = $Err.CategoryInfo.Reason
                            TargetName = $Err.CategoryInfo.TargetName
                        }
                    }
                }
            )
            $TimeEndGraphEssentials = Stop-TimeLog -Time $TimeLogGraphEssentials -Option OneLiner
            $Script:Reporting[$T]['Time'] = $TimeEndGraphEssentials
            Write-Color -Text '[i]', '[End  ] ', $($Script:GraphEssentialsConfiguration[$T]['Name']), " [Time to execute: $TimeEndGraphEssentials]" -Color Yellow, DarkGray, Yellow, DarkGray

            if ($SplitReports) {
                Write-Color -Text '[i]', '[HTML ] ', 'Generating HTML report for ', $T -Color Yellow, DarkGray, Yellow
                $TimeLogHTML = Start-TimeLog
                New-HTMLReportGraphEssentialsWithSplit -FilePath $FilePath -Online:$Online -HideHTML:$HideHTML -CurrentReport $T
                $TimeLogEndHTML = Stop-TimeLog -Time $TimeLogHTML -Option OneLiner
                Write-Color -Text '[i]', '[HTML ] ', 'Generating HTML report for ', $T, " [Time to execute: $TimeLogEndHTML]" -Color Yellow, DarkGray, Yellow, DarkGray
            }
        }
    }
    # Allow external data transformation before HTML is generated
    if ($PostProcess) {
        try {
            & $PostProcess $Script:Reporting
        } catch {
            Write-Warning "Invoke-MyGraphEssentials: PostProcess failed: $($_.Exception.Message)"
        }
    }

    if (-not $SplitReports) {
        Write-Color -Text '[i]', '[HTML ] ', 'Generating HTML report' -Color Yellow, DarkGray, Yellow
        $TimeLogHTML = Start-TimeLog
        if (-not $FilePath) {
            $FilePath = Get-FileName -Extension 'html' -Temporary
        }
        New-HTMLReportGraphEssentials -Type $Type -Online:$Online.IsPresent -HideHTML:$HideHTML.IsPresent -FilePath $FilePath
        $TimeLogEndHTML = Stop-TimeLog -Time $TimeLogHTML -Option OneLiner
        Write-Color -Text '[i]', '[HTML ] ', 'Generating HTML report', " [Time to execute: $TimeLogEndHTML]" -Color Yellow, DarkGray, Yellow, DarkGray
    }
        Reset-GraphEssentials
        # Reset detail preference to avoid bleeding into subsequent calls
        $Script:GraphEssentialsAppsDetailLevel = 'Full'
        $Script:GraphEssentialsAppsApplicationType = 'All'

    if ($PassThru) {
        $Script:Reporting
    }
}

[scriptblock] $SourcesAutoCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $Script:GraphEssentialsConfiguration.Keys | Sort-Object | Where-Object { $_ -like "*$wordToComplete*" }
}

Register-ArgumentCompleter -CommandName Invoke-MyGraphEssentials -ParameterName Type -ScriptBlock $SourcesAutoCompleter
