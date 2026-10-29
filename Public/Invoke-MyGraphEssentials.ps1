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
    When specified, shows safe error notices in the console output. Collection problems always appear in HTML.

    .PARAMETER ShowWarning
    When specified, shows safe warning notices in the console output. Collection problems always appear in HTML.

    .PARAMETER Online
    When specified, opens the generated report in the default web browser.

    .PARAMETER SplitReports
    When specified, generates separate HTML files for each report type instead of a combined report.

    .PARAMETER PostProcess
    Optional scriptblock invoked after data collection and before HTML generation.
    The scriptblock receives $Script:Reporting as its only argument and can modify it to affect output.

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
            $CollectionIssues = [System.Collections.Generic.List[object]]::new()
            $OutputCommand = Invoke-GraphEssentialsReportCollection -Name $T -Issues $CollectionIssues -Collect $Script:GraphEssentialsConfiguration[$T]['Execute']
            if ($OutputCommand -is [System.Collections.IDictionary]) {
                $Script:Reporting[$T]['Data'] = $OutputCommand
            } else {
                $Script:Reporting[$T]['Data'] = [Array] $OutputCommand
            }
            $null = Invoke-GraphEssentialsReportCollection -Name "$T processing" -Issues $CollectionIssues -Collect $Script:GraphEssentialsConfiguration[$T]['Processing']
            $Script:Reporting[$T]['WarningsAndErrors'] = $CollectionIssues.ToArray()
            foreach ($issue in $CollectionIssues) {
                if (($ShowWarning -and $issue.Type -eq 'Warning') -or ($ShowError -and $issue.Type -eq 'Error')) {
                    Write-Warning -Message "$($issue.TargetName): $($issue.Comment)"
                }
            }
            $TimeEndGraphEssentials = Stop-TimeLog -Time $TimeLogGraphEssentials -Option OneLiner
            $Script:Reporting[$T]['Time'] = $TimeEndGraphEssentials
            Write-Color -Text '[i]', '[End  ] ', $($Script:GraphEssentialsConfiguration[$T]['Name']), " [Time to execute: $TimeEndGraphEssentials]" -Color Yellow, DarkGray, Yellow, DarkGray
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

    # Summaries can make additional Graph requests (for example guest policies).
    # Complete them before rendering so every notice reaches the persistent header.
    foreach ($T in $Script:GraphEssentialsConfiguration.Keys) {
        if ($Script:GraphEssentialsConfiguration[$T].Enabled -and $Script:GraphEssentialsConfiguration[$T]['Summary']) {
            $CollectionIssues = [System.Collections.Generic.List[object]]::new()
            foreach ($issue in $Script:Reporting[$T]['WarningsAndErrors']) {
                $CollectionIssues.Add($issue)
            }
            $Script:Reporting[$T]['Summary'] = Invoke-GraphEssentialsReportCollection -Name "$T summary" -Issues $CollectionIssues -Collect $Script:GraphEssentialsConfiguration[$T]['Summary']
            $Script:Reporting[$T]['WarningsAndErrors'] = $CollectionIssues.ToArray()
        }
    }

    if (-not $FilePath) {
        $FilePath = Get-FileName -Extension 'html' -Temporary
    }

    if ($SplitReports) {
        foreach ($T in $Script:GraphEssentialsConfiguration.Keys) {
            if ($Script:GraphEssentialsConfiguration[$T].Enabled -eq $true) {
                Write-Color -Text '[i]', '[HTML ] ', 'Generating HTML report for ', $T -Color Yellow, DarkGray, Yellow
                $TimeLogHTML = Start-TimeLog
                New-HTMLReportGraphEssentialsWithSplit -FilePath $FilePath -Online:$Online -HideHTML:$HideHTML -CurrentReport $T
                $TimeLogEndHTML = Stop-TimeLog -Time $TimeLogHTML -Option OneLiner
                Write-Color -Text '[i]', '[HTML ] ', 'Generating HTML report for ', $T, " [Time to execute: $TimeLogEndHTML]" -Color Yellow, DarkGray, Yellow, DarkGray
            }
        }
    } else {
        Write-Color -Text '[i]', '[HTML ] ', 'Generating HTML report' -Color Yellow, DarkGray, Yellow
        $TimeLogHTML = Start-TimeLog
        New-HTMLReportGraphEssentials -Type $Type -Online:$Online.IsPresent -HideHTML:$HideHTML.IsPresent -FilePath $FilePath
        $TimeLogEndHTML = Stop-TimeLog -Time $TimeLogHTML -Option OneLiner
        Write-Color -Text '[i]', '[HTML ] ', 'Generating HTML report', " [Time to execute: $TimeLogEndHTML]" -Color Yellow, DarkGray, Yellow, DarkGray
    }

    Reset-GraphEssentials
    # Reset detail preference to avoid bleeding into subsequent calls
    $Script:GraphEssentialsAppsDetailLevel = 'Full'
    $Script:GraphEssentialsAppsApplicationType = 'All'
    $Script:GraphEssentialsIncludeOwnerDiagnostics = $false

    if ($PassThru) {
        $Script:Reporting
    }
}

[scriptblock] $SourcesAutoCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $Script:GraphEssentialsConfiguration.Keys | Sort-Object | Where-Object { $_ -like "*$wordToComplete*" }
}

Register-ArgumentCompleter -CommandName Invoke-MyGraphEssentials -ParameterName Type -ScriptBlock $SourcesAutoCompleter
