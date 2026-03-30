BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsErrorDetails.ps1')

    function New-TestErrorRecord {
        param(
            [string] $Message
        )

        try {
            throw [System.Exception]::new($Message)
        } catch {
            return $_
        }
    }
}

Describe 'Get-GraphEssentialsErrorDetails' {
    It 'detects nested permission scope errors from Graph SDK exception text' {
        $errorRecord = New-TestErrorRecord -Message @'
Status: 403 (Forbidden)
ErrorCode: UnknownError
{"errorCode":"PermissionScopeNotGranted","message":"Authorization failed due to missing permission scopes"}
'@

        $result = $errorRecord | Get-GraphEssentialsErrorDetails -FunctionName 'Test-GraphEssentials'

        $result.StatusCode | Should -Be 403
        $result.Code | Should -Be 'PermissionScopeNotGranted'
        $result.IsPermissionDenied | Should -BeTrue
        $result.Message | Should -Match 'missing permission scopes'
    }

    It 'detects missing resources' {
        $errorRecord = New-TestErrorRecord -Message @'
Status: 404 (NotFound)
ErrorCode: Request_ResourceNotFound
Message: Resource could not be found
'@

        $result = $errorRecord | Get-GraphEssentialsErrorDetails -FunctionName 'Test-GraphEssentials'

        $result.StatusCode | Should -Be 404
        $result.Code | Should -Be 'Request_ResourceNotFound'
        $result.IsNotFound | Should -BeTrue
    }

    It 'detects transient transport failures' {
        $errorRecord = New-TestErrorRecord -Message 'Received an unexpected EOF or 0 bytes from the transport stream.'

        $result = $errorRecord | Get-GraphEssentialsErrorDetails -FunctionName 'Test-GraphEssentials'

        $result.IsTransient | Should -BeTrue
        $result.Message | Should -Match 'unexpected EOF'
    }
}
