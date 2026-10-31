function Open-MyAppCertificateRotationLock {
    <# Hold an exclusive cross-process lease until the caller disposes the returned stream. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    $file = Join-Path $Path 'rotation.lock'
    if (Test-Path -LiteralPath $file) {
        if ((Get-Item -LiteralPath $file -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw 'The certificate rotation lock must not be a reparse point.'
        }
    }
    try {
        [IO.FileStream]::new($file, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    } catch {
        throw 'Cannot acquire the certificate rotation profile lock. Another process may be using it.'
    }
}
