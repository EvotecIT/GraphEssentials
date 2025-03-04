function ConvertTo-FlattenedExcludeTargets {
    [CmdletBinding()]
    param (
        [Array]$ExcludeTargets
    )

    if (-not $ExcludeTargets -or $ExcludeTargets.Count -eq 0) {
        return @()
    }

    $ExcludeTargets | ForEach-Object {
        [PSCustomObject]@{
            TargetType  = $_.TargetType
            Id          = $_.Id
            DisplayName = $_.TargetType -eq 'group' ? (Get-MgGroup -GroupId $_.Id -ErrorAction SilentlyContinue).DisplayName : $null
        }
    }
}