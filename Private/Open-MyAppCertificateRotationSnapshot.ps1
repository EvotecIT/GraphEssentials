function Open-MyAppCertificateRotationSnapshot {
    <# Open a bounded immutable checkpoint snapshot. Caller owns and disposes the returned stream. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    $file = Join-Path $Path 'rotation.dpapi'
    $item = Get-Item -LiteralPath $file -Force -ErrorAction Stop
    if (-not ($item -is [IO.FileInfo]) -or $item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'The certificate rotation checkpoint is not a supported regular file.'
    }
    # Writers replace the path; this handle continues reading the original file without blocking them.
    $stream = [IO.File]::Open($file, [IO.FileMode]::Open, [IO.FileAccess]::Read,
        [IO.FileShare]::Read -bor [IO.FileShare]::Delete)
    if ($stream.Length -gt 1MB) {
        $stream.Dispose()
        throw 'The certificate rotation checkpoint exceeds its supported size.'
    }
    $stream
}
