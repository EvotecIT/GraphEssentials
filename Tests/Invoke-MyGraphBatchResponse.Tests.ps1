BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Invoke-MyGraphBatchRequest.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Invoke-MyGraphBatchResponse.ps1')
}

Describe 'Invoke-MyGraphBatchResponse' {
    It 'retries throttled batch subrequests and returns successful results' {
        $initialResponse = [PSCustomObject]@{
            responses = @(
                [PSCustomObject]@{
                    id     = 'summary_0_1'
                    status = 200
                    body   = [PSCustomObject]@{ value = @('ok') }
                },
                [PSCustomObject]@{
                    id      = 'summary_0_2'
                    status  = 429
                    headers = [PSCustomObject]@{ 'Retry-After' = '0' }
                    body    = [PSCustomObject]@{
                        error = [PSCustomObject]@{
                            code    = 'UnknownError'
                            message = 'Too Many Requests'
                        }
                    }
                }
            )
        }

        $retryResponse = [PSCustomObject]@{
            responses = @(
                [PSCustomObject]@{
                    id     = 'summary_0_2'
                    status = 200
                    body   = [PSCustomObject]@{ value = @('retried') }
                }
            )
        }

        $idMap = @{
            summary_0_1 = 'user1'
            summary_0_2 = 'user2'
        }
        $requestsById = @{
            summary_0_1 = @{
                id     = 'summary_0_1'
                method = 'GET'
                url    = '/users/user1/authentication/methods'
            }
            summary_0_2 = @{
                id     = 'summary_0_2'
                method = 'GET'
                url    = '/users/user2/authentication/methods'
            }
        }

        Mock -CommandName Start-Sleep -MockWith {}
        Mock -CommandName Invoke-MyGraphBatchRequest -MockWith { return $retryResponse }

        $results = Invoke-MyGraphBatchResponse -BatchResponses $initialResponse -IdMap $idMap -DataType 'Auth Methods Summary' -RequestsById $requestsById -WarningAction SilentlyContinue

        Assert-MockCalled -CommandName Start-Sleep -Times 1 -Exactly
        Assert-MockCalled -CommandName Invoke-MyGraphBatchRequest -Times 1 -Exactly
        @($results).Count | Should -Be 2
        @($results | Where-Object Success).Count | Should -Be 2
        @($results | Where-Object { $_.Context -eq 'user2' -and $_.Success }).Count | Should -Be 1
    }
}
