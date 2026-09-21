BeforeAll {
    Add-Type -AssemblyName System.Net.Http
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsPagedInventory.ps1')
    function Invoke-MgGraphRequest { param($Method, $Uri, $OutputType, $ErrorAction) }
}

Describe 'Get-GraphEssentialsPagedInventory' {
    It 'retries only the failed page and returns every device once' {
        $script:requestedUris = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-MgGraphRequest {
            $script:requestedUris.Add($Uri)
            if ($Uri -like '*page2*' -and $script:requestedUris.Count -eq 2) {
                throw 'HttpClient.Timeout of 300 seconds elapsing'
            }
            if ($Uri -like '*page2*') {
                return [PSCustomObject] @{ value = @([PSCustomObject] @{ id = 'second' }) }
            }
            [PSCustomObject] @{
                value = @([PSCustomObject] @{ id = 'first' })
                '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/devices?$skiptoken=page2'
            }
        }
        Mock Start-Sleep {}

        $items = @(Get-GraphEssentialsPagedInventory -Uri '/v1.0/devices?$top=200')

        @($items.id) | Should -Be @('first', 'second')
        $script:requestedUris | Should -HaveCount 3
        $script:requestedUris[1] | Should -Be $script:requestedUris[2]
        Should -Invoke Start-Sleep -Times 1 -Exactly
    }

    It 'rejects malformed pages instead of accepting a partial inventory' {
        Mock Invoke-MgGraphRequest { [PSCustomObject] @{ other = @() } }

        { Get-GraphEssentialsPagedInventory -Uri '/v1.0/devices' } |
            Should -Throw '*did not contain a value collection*'
    }

    It 'does not retry a permanent authorization failure' {
        Mock Invoke-MgGraphRequest { throw 'Forbidden' }
        Mock Start-Sleep {}

        { Get-GraphEssentialsPagedInventory -Uri '/v1.0/devices' } |
            Should -Throw '*failed after 1 attempt*'
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly
        Should -Invoke Start-Sleep -Times 0 -Exactly
    }

    It 'retries a wrapped transport failure at the same page' {
        $script:requests = 0
        Mock Invoke-MgGraphRequest {
            $script:requests++
            if ($script:requests -eq 1) {
                throw [System.Exception]::new('An error occurred while sending the request',
                    [System.IO.IOException]::new('The response ended prematurely'))
            }
            [PSCustomObject] @{ value = @([PSCustomObject] @{ id = 'device-1' }) }
        }
        Mock Start-Sleep {}

        $items = @(Get-GraphEssentialsPagedInventory -Uri '/v1.0/devices')

        $items | Should -HaveCount 1
        Should -Invoke Invoke-MgGraphRequest -Times 2 -Exactly
        Should -Invoke Start-Sleep -Times 1 -Exactly
    }

    It 'does not retry an HTTP authorization error with a nested transport exception' {
        Mock Invoke-MgGraphRequest {
            $exception = [System.Exception]::new('Forbidden', [System.IO.IOException]::new('Connection closed'))
            $exception | Add-Member -NotePropertyName Response -NotePropertyValue ([PSCustomObject] @{ StatusCode = 403 })
            throw $exception
        }
        Mock Start-Sleep {}

        { Get-GraphEssentialsPagedInventory -Uri '/v1.0/devices' } | Should -Throw '*failed after 1 attempt*'
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly
        Should -Invoke Start-Sleep -Times 0 -Exactly
    }

    It 'stops when Graph repeats a next page URL' {
        Mock Invoke-MgGraphRequest {
            [PSCustomObject] @{
                value = @()
                '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/devices?$skiptoken=same'
            }
        }

        { Get-GraphEssentialsPagedInventory -Uri '/v1.0/devices' } |
            Should -Throw '*repeated page URL*'
        Should -Invoke Invoke-MgGraphRequest -Times 2 -Exactly
    }

    It 'honors Retry-After when Graph throttles a page' {
        $script:requests = 0
        $script:delays = [System.Collections.Generic.List[int]]::new()
        Mock Invoke-MgGraphRequest {
            $script:requests++
            if ($script:requests -eq 1) {
                $exception = [System.Exception]::new('throttled')
                $exception | Add-Member -NotePropertyName Response -NotePropertyValue ([PSCustomObject] @{
                    StatusCode = 429
                    Headers = @{ 'Retry-After' = '7' }
                })
                throw $exception
            }
            [PSCustomObject] @{ value = @([PSCustomObject] @{ id = 'device-1' }) }
        }
        Mock Start-Sleep { $script:delays.Add($Seconds) }

        $items = @(Get-GraphEssentialsPagedInventory -Uri '/v1.0/devices')

        $items | Should -HaveCount 1
        $script:delays | Should -Be @(7)
        Should -Invoke Invoke-MgGraphRequest -Times 2 -Exactly
    }

    It 'honors Retry-After from a real HttpResponseHeaders object' {
        $script:requests = 0
        $script:delays = [System.Collections.Generic.List[int]]::new()
        Mock Invoke-MgGraphRequest {
            $script:requests++
            if ($script:requests -eq 1) {
                $response = [System.Net.Http.HttpResponseMessage]::new()
                $response.Headers.RetryAfter = [System.Net.Http.Headers.RetryConditionHeaderValue]::new([TimeSpan]::FromSeconds(11))
                $exception = [System.Exception]::new('throttled')
                $exception | Add-Member -NotePropertyName Response -NotePropertyValue ([PSCustomObject] @{
                    StatusCode = 429
                    Headers = $response.Headers
                })
                throw $exception
            }
            [PSCustomObject] @{ value = @([PSCustomObject] @{ id = 'device-1' }) }
        }
        Mock Start-Sleep { $script:delays.Add($Seconds) }

        $items = @(Get-GraphEssentialsPagedInventory -Uri '/v1.0/devices')

        $items | Should -HaveCount 1
        $script:delays | Should -Be @(11)
        Should -Invoke Invoke-MgGraphRequest -Times 2 -Exactly
    }
}
