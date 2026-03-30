$PrimaryModule = Get-ChildItem -Path $PSScriptRoot -Filter '*.psd1' -File -ErrorAction Stop
if ($PrimaryModule.Count -ne 1) {
    throw 'Expected exactly one PSD1 file in the repository root.'
}

$availablePester = Get-Module -ListAvailable -Name Pester | Where-Object {
    $_.Version -ge [version] '5.0.0'
} | Select-Object -First 1

if (-not $availablePester) {
    Install-Module -Name Pester -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
}

Import-Module Pester -Force -ErrorAction Stop

$configuration = [PesterConfiguration]::Default
$configuration.Run.Path = (Join-Path $PSScriptRoot 'Tests')
$configuration.Run.Exit = $true
$configuration.Should.ErrorAction = 'Continue'
$configuration.CodeCoverage.Enabled = $false
$configuration.Output.Verbosity = 'Detailed'

$result = Invoke-Pester -Configuration $configuration
if ($result.FailedCount -gt 0) {
    throw "$($result.FailedCount) tests failed."
}
