function Invoke-GraphEssentialsInvitationBatch {
    <# Execute one approved batch. Retry only explicit throttling; retain ambiguous outcomes for reconciliation. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]] $Pending,
        [Parameter(Mandatory)] $Connection,
        [Parameter(Mandatory)][int] $MaxRetries,
        [Parameter(Mandatory)][int] $MaxRetryDelaySeconds,
        [scriptblock] $PendingBatchAction
    )

    while ($Pending.Count -gt 0) {
        $requests = foreach ($state in $Pending) {
            $state.AttemptCount++
            $state.RequestId = '{0}-{1}' -f $state.InputIndex, $state.AttemptCount
            @{
                id      = $state.RequestId
                method  = 'POST'
                url     = '/invitations'
                headers = @{ 'Content-Type' = 'application/json' }
                body    = $state.Body
            }
        }
        # Freeze the wire payload before the checkpoint callback, which receives its own body snapshots.
        $body = @{ requests = @($requests) } | ConvertTo-Json -Depth 8 -Compress
        if ($PendingBatchAction) {
            $wire = $body | ConvertFrom-Json
            $intent = for ($index = 0; $index -lt $Pending.Count; $index++) {
                $state = $Pending[$index]
                [pscustomobject] @{
                    InputIndex   = $state.InputIndex
                    Context      = $state.Context
                    EmailAddress = $state.EmailAddress
                    RequestId    = $state.RequestId
                    AttemptCount = $state.AttemptCount
                    Body         = $wire.requests[$index].body
                }
            }
            $null = & $PendingBatchAction ([object[]] @($intent))
        }
        try {
            $batch = Send-GraphEssentialsInvitationBatch -Body $body -Connection $Connection
        } catch {
            foreach ($state in $Pending) {
                New-GraphEssentialsInvitationResult -State $state -Status Uncertain -ErrorCode 'BatchTransportUncertain' -ErrorMessage 'No complete batch receipt was obtained. Reconcile the saved invitation intent before resubmitting.'
            }
            break
        }
        $responses = @{}
        $duplicates = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $batchResponses = Get-GraphEssentialsObjectValue -InputObject $batch -Name 'responses'
        foreach ($response in $batchResponses) {
            $id = [string] (Get-GraphEssentialsObjectValue -InputObject $response -Name 'id')
            if ($responses.ContainsKey($id)) {
                $null = $duplicates.Add($id)
            } else {
                $responses[$id] = $response
            }
        }
        $retry = [System.Collections.Generic.List[object]]::new()
        $delay = 0
        foreach ($state in $Pending) {
            $response = $responses[$state.RequestId]
            $statusCode = 0
            $statusValue = Get-GraphEssentialsObjectValue -InputObject $response -Name 'status'
            $validStatus = [int]::TryParse([string] $statusValue, [ref] $statusCode) -and $statusCode -ge 200 -and $statusCode -le 599
            if (-not $response -or $duplicates.Contains($state.RequestId) -or -not $validStatus) {
                New-GraphEssentialsInvitationResult -State $state -Status Uncertain -ErrorCode 'InvalidBatchReceipt' -ErrorMessage 'The invitation has no unique response with a valid HTTP status. Reconcile before resubmitting.'
                continue
            }
            $responseBody = Get-GraphEssentialsObjectValue -InputObject $response -Name 'body'
            $user = Get-GraphEssentialsObjectValue -InputObject $responseBody -Name 'invitedUser'
            $userId = [string] (Get-GraphEssentialsObjectValue -InputObject $user -Name 'id')
            if ($statusCode -eq 201 -and -not [string]::IsNullOrWhiteSpace($userId)) {
                New-GraphEssentialsInvitationResult -State $state -Status Succeeded -StatusCode $statusCode -Invitation $responseBody
            } elseif ($statusCode -eq 429) {
                $retryAfter = Get-BatchRetryDelaySeconds -BatchResponse $response
                if ($state.AttemptCount -le $MaxRetries -and $retryAfter -le $MaxRetryDelaySeconds) {
                    $retry.Add($state)
                    $delay = [math]::Max($delay, $retryAfter)
                } else {
                    New-GraphEssentialsInvitationResult -State $state -Status Deferred -StatusCode $statusCode -RetryAfterSeconds $retryAfter -ErrorCode 'Throttled' -ErrorMessage 'The invitation was throttled. Reschedule after RetryAfterSeconds; it was not automatically resubmitted.'
                }
            } elseif ($statusCode -eq 408 -or $statusCode -ge 500 -or $statusCode -lt 400) {
                New-GraphEssentialsInvitationResult -State $state -Status Uncertain -StatusCode $statusCode -ErrorCode 'AmbiguousInvitationResponse' -ErrorMessage 'The response does not establish a completed invitation or a safe retry. Reconcile before resubmitting.'
            } else {
                $errorBody = Get-GraphEssentialsObjectValue -InputObject $responseBody -Name 'error'
                New-GraphEssentialsInvitationResult -State $state -Status Failed -StatusCode $statusCode -ErrorCode (Get-GraphEssentialsObjectValue -InputObject $errorBody -Name 'code') -ErrorMessage (Get-GraphEssentialsObjectValue -InputObject $errorBody -Name 'message')
            }
        }
        if ($retry.Count -gt 0) {
            Start-Sleep -Seconds $delay
            foreach ($state in $retry) {
                $state.RetryDelaySeconds += $delay
            }
        }
        $Pending = $retry.ToArray()
    }
}
