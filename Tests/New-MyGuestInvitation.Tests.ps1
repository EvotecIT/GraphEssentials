BeforeAll {
    foreach ($name in @('Get-GraphEssentialsObjectValue', 'ConvertTo-GraphEssentialsInvitationBody',
            'New-GraphEssentialsInvitationResult', 'Send-GraphEssentialsInvitationBatch',
            'Invoke-GraphEssentialsInvitationBatch', 'Get-BatchRetryDelaySeconds')) {
        . (Join-Path $PSScriptRoot "..\Private\$name.ps1")
    }
    . (Join-Path $PSScriptRoot '..\Public\New-MyGuestInvitation.ps1')
    function Get-MgContext {}
    function Get-MgRequestContext {}
    function Set-MgRequestContext {
        [CmdletBinding(SupportsShouldProcess)]
        param($MaxRetry)
    }
    function Invoke-MgGraphRequest {
        [CmdletBinding()]
        param($Method, $Uri, $Body, $ContentType, $OutputType)
    }
}

Describe 'SDK invitation workflow' {
    BeforeEach {
        $script:Sent = [System.Collections.Generic.List[object]]::new()
        $script:Replies = [System.Collections.Generic.Queue[object]]::new()
        $script:RequestContext = [pscustomobject] @{ MaxRetry = 3 }
        $script:Connection = [pscustomobject] @{
            TenantId = 'tenant-one'; ClientId = 'client-one'; Account = $null; AuthType = 'AppOnly'; Environment = 'Global'
        }
        $script:TransportFails = $false
        $script:Events = [System.Collections.Generic.List[string]]::new()
        Mock Get-MgContext { $script:Connection }
        Mock Get-MgRequestContext { $script:RequestContext }
        Mock Set-MgRequestContext { $script:RequestContext.MaxRetry = $MaxRetry }
        Mock Start-Sleep {}
        Mock Invoke-MgGraphRequest {
            $script:RequestContext.MaxRetry | Should -Be 0
            $Method | Should -Be 'POST'
            $Uri | Should -Be '/v1.0/$batch'
            $ContentType | Should -Be 'application/json'
            $payload = $Body | ConvertFrom-Json
            $script:Sent.Add(@($payload.requests))
            $script:Events.Add('dispatch')
            if ($script:TransportFails) {
                throw 'sensitive-transport-body'
            }
            if ($script:Replies.Count -gt 0) {
                return $script:Replies.Dequeue()
            }
            $responses = foreach ($request in $payload.requests) {
                $request.method | Should -Be 'POST'
                $request.url | Should -Be '/invitations'
                [pscustomobject] @{
                    id = $request.id
                    status = 201
                    body = [pscustomobject] @{
                        invitedUser = [pscustomobject] @{ id = 'guest-' + $request.id }
                        inviteRedeemUrl = 'https://example.com/redemption'
                    }
                }
            }
            [pscustomobject] @{ responses = @($responses) }
        }
    }

    It 'validates CSV records preserves order and returns explicit invited-user identities' {
        $items = @(
            @{EmailAddress='first@example.com';Context='row-one';SendInvitationMessage='False'}
            @{EmailAddress='invalid@example.com';SendInvitationMessage='maybe'}
            [pscustomobject] @{EmailAddress='third@example.com';Context=0;ResetRedemption='True';InvitedUserId='00000000-0000-0000-0000-000000000123'}
        )
        $results = @(New-MyGuestInvitation -Invitation $items)
        $results.Count | Should -Be 3
        ($results.InputIndex -join ',') | Should -Be '0,1,2'
        ($results.Status -join ',') | Should -Be 'Succeeded,Failed,Succeeded'
        $results[0].Context | Should -Be 'row-one'
        $results[2].Context | Should -Be 0
        $results[0].InvitedUserId | Should -Be 'guest-0-1'
        $results[1].ErrorCode | Should -Be 'InvalidInvitation'
        $results[1].AttemptCount | Should -Be 0
        $script:Sent[0].Count | Should -Be 2
        $script:Sent[0][0].body.sendInvitationMessage | Should -BeFalse
        $script:Sent[0][1].body.resetRedemption | Should -BeTrue
        $script:Sent[0][1].body.invitedUser.id | Should -Be '00000000-0000-0000-0000-000000000123'
        $script:RequestContext.MaxRetry | Should -Be 3
    }

    It 'checkpoints only the current batch before dispatch and outcomes before the next batch' {
        $items = @(0..20 | ForEach-Object { @{EmailAddress="guest$_@example.com";Context=$_} })
        $results = @(New-MyGuestInvitation -Invitation $items -PendingBatchAction {
                param($intent)
                $script:Events.Add('pending-' + $intent.Count)
            } -ResultBatchAction {
                param($outcomes)
                $script:Events.Add('results-' + $outcomes.Count)
            })
        $results.Count | Should -Be 21
        ($script:Events -join ',') | Should -Be 'pending-20,dispatch,results-20,pending-1,dispatch,results-1'
        ($results.InputIndex -join ',') | Should -Be ((0..20) -join ',')
        $script:Sent[0].Count | Should -Be 20
        $script:Sent[1].Count | Should -Be 1
    }

    It 'retries only throttled invitations after Retry-After and checkpoints that exact subset' {
        $script:Replies.Enqueue(@{responses=@(
                    @{id='0-1';status=201;body=@{invitedUser=@{id='first-guest'}}}
                    @{id='1-1';status=429;headers=@{'rEtRy-AfTeR'=@('7')}}
                )})
        $results = @(New-MyGuestInvitation -Invitation @(@{EmailAddress='first@example.com'},@{EmailAddress='second@example.com'}) -PendingBatchAction {
                param($intent)
                $script:Events.Add('pending-' + ($intent.InputIndex -join '-'))
            })
        ($script:Events -join ',') | Should -Be 'pending-0-1,dispatch,pending-1,dispatch'
        $script:Sent[1].Count | Should -Be 1
        $script:Sent[1][0].id | Should -Be '1-2'
        $results[0].AttemptCount | Should -Be 1
        $results[1].AttemptCount | Should -Be 2
        $results[1].RetryDelaySeconds | Should -Be 7
        $results[1].Status | Should -Be 'Succeeded'
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 7 }
        $script:RequestContext.MaxRetry | Should -Be 3
    }

    It 'defers a throttled invitation rather than shortening a server delay beyond the wait budget' {
        $script:Replies.Enqueue(@{responses=@(@{id='0-1';status=429;headers=@{'Retry-After'='301'}})})
        $result = New-MyGuestInvitation -Invitation @{EmailAddress='guest@example.com'} -MaxRetryDelaySeconds 300
        $result.Status | Should -Be 'Deferred'
        $result.RetryAfterSeconds | Should -Be 301
        $result.RequiresReconciliation | Should -BeFalse
        $script:Sent.Count | Should -Be 1
        Should -Invoke Start-Sleep -Times 0 -Exactly
    }

    It 'honors an HTTP-date retry header without retrying early' {
        $retryAt = [datetimeoffset]::UtcNow.AddSeconds(1000).ToString('r')
        $script:Replies.Enqueue(@{responses=@(@{id='0-1';status=429;headers=[pscustomobject]@{'Retry-After'=$retryAt}})})
        $result = New-MyGuestInvitation -Invitation @{EmailAddress='guest@example.com'} -MaxRetryDelaySeconds 5
        $result.Status | Should -Be 'Deferred'
        $result.RetryAfterSeconds | Should -BeGreaterThan 900
        $result.RetryAfterSeconds | Should -BeLessOrEqual 1000
        Should -Invoke Start-Sleep -Times 0 -Exactly
    }

    It 'rounds millisecond retry hints up and stops at the retry limit' {
        $script:Replies.Enqueue(@{responses=@(@{id='0-1';status=429;headers=@{'X-MS-RETRY-AFTER-MS'='1500'}})})
        $script:Replies.Enqueue(@{responses=@(@{id='0-2';status=429;headers=@{'Retry-After'='3'}})})
        $result = New-MyGuestInvitation -Invitation @{EmailAddress='guest@example.com'} -MaxRetries 1
        $result.Status | Should -Be 'Deferred'
        $result.AttemptCount | Should -Be 2
        $result.RetryDelaySeconds | Should -Be 2
        $result.RetryAfterSeconds | Should -Be 3
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 2 }
        $script:Sent.Count | Should -Be 2
    }

    It 'keeps HTTP <Code> uncertain and never automatically replays the invitation' -ForEach @(
        @{Code=408}, @{Code=500}, @{Code=502}, @{Code=503}, @{Code=504}
    ) {
        $script:Replies.Enqueue(@{responses=@(@{id='0-1';status=$Code;body=@{error=@{code='Ambiguous'}}})})
        $result = New-MyGuestInvitation -Invitation @{EmailAddress='guest@example.com'}
        $result.Status | Should -Be 'Uncertain'
        $result.RequiresReconciliation | Should -BeTrue
        $result.AttemptCount | Should -Be 1
        $script:Sent.Count | Should -Be 1
        Should -Invoke Start-Sleep -Times 0 -Exactly
    }

    It 'keeps missing duplicate and malformed-success receipts uncertain' {
        $script:Replies.Enqueue(@{responses=@(
                    @{id='0-1';status=201;body=@{invitedUser=@{id='one'}}}
                    @{id='0-1';status=201;body=@{invitedUser=@{id='two'}}}
                    @{id='2-1';status=201;body=@{invitedUser=@{id=''}}}
                )})
        $results = @(New-MyGuestInvitation -Invitation @(@{EmailAddress='one@example.com'},@{EmailAddress='two@example.com'},@{EmailAddress='three@example.com'}))
        ($results.Status -join ',') | Should -Be 'Uncertain,Uncertain,Uncertain'
        @($results | Where-Object RequiresReconciliation).Count | Should -Be 3
        $script:Sent.Count | Should -Be 1
    }

    It 'reports a rejected invitation as failed with its Graph error rather than warning-based success' {
        $script:Replies.Enqueue(@{responses=@(@{id='0-1';status=403;body=@{error=@{code='Authorization_RequestDenied';message='Insufficient permission'}}})})
        $result = New-MyGuestInvitation -Invitation @{EmailAddress='guest@example.com'}
        $result.Status | Should -Be 'Failed'
        $result.Success | Should -BeFalse
        $result.RequiresReconciliation | Should -BeFalse
        $result.ErrorCode | Should -Be 'Authorization_RequestDenied'
        $result.StatusCode | Should -Be 403
    }

    It 'retains transport uncertainty without exposing transport bodies and restores SDK settings' {
        $script:TransportFails = $true
        $result = New-MyGuestInvitation -Invitation @{EmailAddress='guest@example.com'}
        $result.Status | Should -Be 'Uncertain'
        $result.ErrorMessage | Should -Not -Match 'sensitive-transport-body'
        $script:RequestContext.MaxRetry | Should -Be 3
        $script:Sent.Count | Should -Be 1
    }

    It 'does not dispatch if the pending checkpoint fails' {
        { New-MyGuestInvitation -Invitation @{EmailAddress='guest@example.com'} -PendingBatchAction { throw 'checkpoint failed' } } | Should -Throw '*checkpoint failed*'
        Should -Invoke Invoke-MgGraphRequest -Times 0 -Exactly
        Should -Invoke Set-MgRequestContext -Times 0 -Exactly
    }

    It 'stops before later batches when the result checkpoint fails after dispatch' {
        $items = @(0..20 | ForEach-Object { @{EmailAddress="guest$_@example.com"} })
        { New-MyGuestInvitation -Invitation $items -ResultBatchAction { throw 'result checkpoint failed' } } | Should -Throw '*result checkpoint failed*'
        $script:Sent.Count | Should -Be 1
        $script:Sent[0].Count | Should -Be 20
        $script:RequestContext.MaxRetry | Should -Be 3
    }

    It 'previews without SDK access settings changes or checkpoint callbacks' {
        $result = New-MyGuestInvitation -Invitation @{EmailAddress='guest@example.com'} -WhatIf -PendingBatchAction { throw 'unexpected checkpoint' } -ResultBatchAction { throw 'unexpected result write' }
        $result.Status | Should -Be 'WhatIf'
        $result.AttemptCount | Should -Be 0
        Should -Invoke Get-MgContext -Times 0 -Exactly
        Should -Invoke Get-MgRequestContext -Times 0 -Exactly
        Should -Invoke Set-MgRequestContext -Times 0 -Exactly
        Should -Invoke Invoke-MgGraphRequest -Times 0 -Exactly
    }

    It 'handles an empty input without producing outcomes or contacting the SDK' {
        @(New-MyGuestInvitation -Invitation @()).Count | Should -Be 0
        Should -Invoke Get-MgContext -Times 0 -Exactly
    }
}
