function Save-MyAppCertificateRotationState {
    <# Atomically replace the single protected profile. A failed save preserves the last durable intent. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)] $State
    )

    $json = ConvertTo-Json -InputObject $State -Depth 8 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    try {
        $protected = [Security.Cryptography.ProtectedData]::Protect(
            $bytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    } finally {
        [Array]::Clear($bytes, 0, $bytes.Length)
    }
    $file = Join-Path $Path 'rotation.dpapi'
    $temporary = Join-Path $Path ('rotation.' + [guid]::NewGuid().ToString('N') + '.pending')
    try {
        $stream = [IO.FileStream]::new($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $stream.Write($protected, 0, $protected.Length)
            $stream.Flush($true)
        } finally {
            $stream.Dispose()
        }
        if ([IO.File]::Exists($file)) {
            [IO.File]::Replace($temporary, $file, [NullString]::Value)
        } else {
            [IO.File]::Move($temporary, $file)
        }
    } finally {
        if ([IO.File]::Exists($temporary)) {
            [IO.File]::Delete($temporary)
        }
    }
}
