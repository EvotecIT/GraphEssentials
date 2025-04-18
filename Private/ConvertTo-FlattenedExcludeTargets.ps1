function ConvertTo-FlattenedExcludeTargets {
    <#
    .SYNOPSIS
    Converts exclude targets to a flattened structure with display names for groups.

    .DESCRIPTION
    Takes an array of exclude targets and creates a flattened structure that includes display names for group targets.
    Returns an empty array if no exclude targets are provided.

    .PARAMETER ExcludeTargets
    Array of exclude target objects containing TargetType and Id properties.

    #>
    [CmdletBinding()]
    param (
        [Array]$ExcludeTargets
    )

    if (-not $ExcludeTargets -or $ExcludeTargets.Count -eq 0) {
        return @()
    }

    $ExcludeTargets | ForEach-Object {
        $DisplayName = $null
        if ($_.TargetType -eq 'group') {
            $DisplayName = (Get-MgGroup -GroupId $_.Id -ErrorAction SilentlyContinue).DisplayName
        }

        [PSCustomObject]@{
            TargetType  = $_.TargetType
            Id          = $_.Id
            DisplayName = $DisplayName
        }
    }
}