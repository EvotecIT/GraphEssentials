BeforeAll {
    Add-Type -AssemblyName System.Net.Http
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsPagedInventory.ps1')
    function Invoke-MgGraphRequest { param($Method, $Uri, $OutputType, $ErrorAction) }
}

Describe 'Get-GraphEssentialsPagedInventory' {
    It 'reports an intermediate checkpoint during a long inventory' {
        Mock Invoke-MgGraphRequest {
            $page = if ($Uri -match 'page=(\d+)') { [int] $Matches[1] } else { 1 }
            [PSCustomObject] @{
                value = @([PSCustomObject] @{ id = "device-$page" })
                '@odata.nextLink' = if ($page -lt 11) { "https://graph.microsoft.com/v1.0/devices?page=$($page + 1)" } else { $null }
            }
        }

        $records = @(Get-GraphEssentialsPagedInventory -Uri '/v1.0/devices?page=1' -ReportProgress 6>&1)
        $items = @($records | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })
        $messages = @($records | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } | ForEach-Object { [string] $_.MessageData })

        $items | Should -HaveCount 11
        ($messages -join "`n") | Should -Match '10 records across 10 page\(s\).+continuing'
        ($messages -join "`n") | Should -Match '11 records across 11 page\(s\).+complete'
    }

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

        $records = @(Get-GraphEssentialsPagedInventory -Uri '/v1.0/devices?$top=200' -ReportProgress 6>&1)
        $items = @($records | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })
        $messages = @($records | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } | ForEach-Object { [string] $_.MessageData })

        @($items.id) | Should -Be @('first', 'second')
        ($messages -join "`n") | Should -Match 'requesting page 1'
        ($messages -join "`n") | Should -Match 'retrying page 2'
        ($messages -join "`n") | Should -Match '2 records across 2 page'
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

    It 'honors Retry-After when Graph returns service unavailable' {
        $script:requests = 0
        $script:delays = [System.Collections.Generic.List[int]]::new()
        Mock Invoke-MgGraphRequest {
            $script:requests++
            if ($script:requests -eq 1) {
                $response = [System.Net.Http.HttpResponseMessage]::new()
                $response.Headers.RetryAfter = [System.Net.Http.Headers.RetryConditionHeaderValue]::new([TimeSpan]::FromSeconds(17))
                $exception = [System.Exception]::new('service unavailable')
                $exception | Add-Member -NotePropertyName Response -NotePropertyValue ([PSCustomObject] @{
                    StatusCode = 503
                    Headers = $response.Headers
                })
                throw $exception
            }
            [PSCustomObject] @{ value = @([PSCustomObject] @{ id = 'device-1' }) }
        }
        Mock Start-Sleep { $script:delays.Add($Seconds) }

        $items = @(Get-GraphEssentialsPagedInventory -Uri '/v1.0/devices')

        $items | Should -HaveCount 1
        $script:delays | Should -Be @(17)
        Should -Invoke Invoke-MgGraphRequest -Times 2 -Exactly
    }
}
