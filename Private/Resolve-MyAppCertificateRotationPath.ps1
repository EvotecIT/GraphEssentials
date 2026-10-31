function Resolve-MyAppCertificateRotationPath {
    <# Resolve a local Windows profile directory without following reparse points. No files are created. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        throw 'Certificate rotation profiles require Windows DPAPI and the same Windows account on every run.'
    }
    if (-not ('System.Security.Cryptography.ProtectedData' -as [type])) {
        if ($PSEdition -eq 'Desktop') {
            Add-Type -AssemblyName System.Security -ErrorAction Stop
        } else {
            Add-Type -AssemblyName System.Security.Cryptography.ProtectedData -ErrorAction Stop
        }
    }
    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    if ($fullPath.StartsWith('\\') -or $fullPath.Length -le [IO.Path]::GetPathRoot($fullPath).Length) {
        throw 'Use a dedicated local profile directory, not a share or volume root.'
    }
    $candidate = $fullPath
    while ($candidate) {
        if (Test-Path -LiteralPath $candidate) {
            $item = Get-Item -LiteralPath $candidate -Force -ErrorAction Stop
            if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw 'Certificate rotation paths must contain directories without reparse points.'
            }
        }
        $candidate = [IO.Path]::GetDirectoryName($candidate)
    }
    $fullPath
}
