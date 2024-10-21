function Invoke-MyGraphEssentials {
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
        [switch] $SplitReports
    )
    Reset-GraphEssentials

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
    if ( -not $SplitReports) {
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

    if ($PassThru) {
        $Script:Reporting
    }
}

[scriptblock] $SourcesAutoCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $Script:GraphEssentialsConfiguration.Keys | Sort-Object | Where-Object { $_ -like "*$wordToComplete*" }
}

Register-ArgumentCompleter -CommandName Invoke-MyGraphEssentials -ParameterName Type -ScriptBlock $SourcesAutoCompleter