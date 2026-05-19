function Test-GraphEssentialsAutopilotSerialNumber {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $SerialNumber
    )

    if ([string]::IsNullOrWhiteSpace($SerialNumber)) {
        return $false
    }

    $normalized = $SerialNumber.Trim()
    $placeholderSerials = @(
        '0',
        'unknown',
        'none',
        'n/a',
        'na',
        'defaultstring',
        'systemserialnumber',
        'to be filled by o.e.m.',
        'tobefilledbyoem'
    )

    $placeholderSerials -notcontains $normalized.ToLowerInvariant()
}
