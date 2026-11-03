function Resolve-MyAppCertificateSessionOptions {
    <# Validate the JSON-friendly session contract before any credential or Graph operation. #>
    [CmdletBinding()]
    param([System.Collections.IDictionary] $Configuration, [string] $ConfigurationDirectory)

    if (-not $Configuration) { return @{ Enabled = $false } }
    $allowed = @('Enabled', 'ProfilePath', 'ApplicationObjectId', 'KeyId', 'CertificateLifetimeDays', 'RenewBeforeDays', 'OverlapDays')
    foreach ($key in $Configuration.Keys) {
        if ($key -notin $allowed) { throw "Unknown certificate rotation setting: $key" }
    }
    if ($Configuration.Contains('Enabled') -and $Configuration.Enabled -isnot [bool]) {
        throw 'CertificateRotation.Enabled must be true or false.'
    }
    if ($Configuration.Enabled -ne $true) { return @{ Enabled = $false } }
    if ([string]::IsNullOrWhiteSpace([string] $Configuration.ProfilePath)) {
        throw 'CertificateRotation.ProfilePath is required when enabled.'
    }
    $path = [string] $Configuration.ProfilePath
    if (-not [IO.Path]::IsPathRooted($path)) {
        if ([string]::IsNullOrWhiteSpace($ConfigurationDirectory)) {
            throw 'Supply an absolute ProfilePath or the configuration directory for relative paths.'
        }
        $path = Join-Path $ConfigurationDirectory $path
    }
    $options = @{ Enabled = $true; Path = [IO.Path]::GetFullPath($path) }
    foreach ($name in @('ApplicationObjectId', 'KeyId')) {
        if ($Configuration.Contains($name)) {
            $id = [guid]::Empty
            if (-not [guid]::TryParse([string] $Configuration[$name], [ref] $id) -or $id -eq [guid]::Empty) {
                throw "CertificateRotation.$name must be a nonempty GUID."
            }
            $options[$name] = $id
        }
    }
    $policy = @{ CertificateLifetimeDays = 30; RenewBeforeDays = 14; OverlapDays = 1 }
    foreach ($name in @('CertificateLifetimeDays', 'RenewBeforeDays', 'OverlapDays')) {
        if ($Configuration.Contains($name)) {
            $value = $Configuration[$name]
            if (($value -isnot [int] -and $value -isnot [long]) -or $value -lt 1 -or $value -gt 3650) {
                throw "CertificateRotation.$name must be a whole number from 1 to 3650."
            }
            $policy[$name] = [int] $value
        }
    }
    $options.Policy = $policy
    $options
}
