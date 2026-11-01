function New-MyGuestInvitation {
    <#
    .SYNOPSIS
    Submits guest invitations through bounded SDK batches with explicit per-input outcomes.
    .DESCRIPTION
    Accepts one or more records with EmailAddress, optional DisplayName, SendInvitationMessage,
    InviteRedirectUrl, UserType, ResetRedemption, InvitedUserId and opaque Context. CSV Boolean text
    True/False is supported; email delivery defaults to false. Redirect defaults to myapps.microsoft.com.
    Returns one ordered outcome per input. Only explicit HTTP 429 responses are retried. Lost responses,
    malformed successes, duplicate receipts, HTTP 408 and server failures require reconciliation, not replay.
    Run immediately after a fresh Connect-MgGraph in a dedicated process without concurrent SDK runspaces.
    .PARAMETER Invitation
    Invitation records. ResetRedemption requires the existing user's object ID in InvitedUserId.
    Optional UserType accepts Guest or Member; inviting members can require additional permissions.
    .PARAMETER BatchSize
    Maximum invitations per Graph JSON batch, from 1 to 20. Defaults to 20.
    .PARAMETER MaxRetries
    Additional attempts after explicit throttling. Defaults to 3. Transport or ambiguous outcomes are never retried.
    .PARAMETER MaxRetryDelaySeconds
    Maximum wait accepted within this invocation. Defaults to 300. A longer Retry-After returns Deferred,
    preserving the server's delay so the caller can reschedule without retrying too early.
    .PARAMETER PendingBatchAction
    Optional checkpoint callback receiving the exact input indices, context, request IDs, attempt counts and
    public request bodies immediately before each dispatch, including throttled subsets. Throwing prevents
    that dispatch and terminates processing. Correlation IDs are not server-side idempotency keys.
    .PARAMETER ResultBatchAction
    Optional callback receiving ordered final outcomes for each dispatched batch before output and before
    the next batch starts. If it throws, processing stops; reconcile the durable pending intent before rerun.
    Callbacks must not change the SDK connection or mutate results. No callbacks run during WhatIf or a declined batch.
    .EXAMPLE
    $results = New-MyGuestInvitation -Invitation @(@{ EmailAddress = 'guest@example.com'; DisplayName = 'Guest One'; Context = 'row-1' })
    Invites one guest without sending email and returns its explicit outcome and invited-user ID.
    .EXAMPLE
    New-MyGuestInvitation -Invitation $invitations -WhatIf
    Validates and previews batches without contacting Graph, changing SDK request settings or invoking callbacks.
    .EXAMPLE
    $results = New-MyGuestInvitation -Invitation $invitations -PendingBatchAction $saveIntent -ResultBatchAction $saveResults
    Lets the host persist intent before writes and final outcomes before advancing to the next batch.
    .OUTPUTS
    System.Management.Automation.PSCustomObject. InputIndex, Context, EmailAddress, Status, Success,
    RequiresReconciliation, StatusCode, AttemptCount, RetryDelaySeconds, RetryAfterSeconds, RequestId,
    InvitedUserId, Invitation, ErrorCode and ErrorMessage. Invitation can contain a sensitive redemption URL.
    .NOTES
    Uses the existing Microsoft.Graph.Authentication dependency and the current SDK identity/permissions.
    The host owns durable checkpoints and recovery; this command does not persist files or automatically resume
    uncertain invitations. Filter Status and InvitedUserId for logs rather than logging complete Invitation bodies.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]] $Invitation,
        [ValidateRange(1, 20)][int] $BatchSize = 20,
        [ValidateRange(0, 10)][int] $MaxRetries = 3,
        [ValidateRange(1, 3600)][int] $MaxRetryDelaySeconds = 300,
        [scriptblock] $PendingBatchAction,
        [scriptblock] $ResultBatchAction
    )

    $connection = $null
    for ($offset = 0; $offset -lt $Invitation.Count; $offset += $BatchSize) {
        $pending = [System.Collections.Generic.List[object]]::new()
        $results = [System.Collections.Generic.List[object]]::new()
        $end = [math]::Min($Invitation.Count, $offset + $BatchSize)
        for ($index = $offset; $index -lt $end; $index++) {
            $item = $Invitation[$index]
            $state = [pscustomobject] @{
                InputIndex        = $index
                Context           = Get-GraphEssentialsObjectValue -InputObject $item -Name 'Context'
                EmailAddress      = Get-GraphEssentialsObjectValue -InputObject $item -Name 'EmailAddress'
                Body              = $null
                RequestId         = $null
                AttemptCount      = 0
                RetryDelaySeconds = 0
            }
            try {
                $state.Body = ConvertTo-GraphEssentialsInvitationBody -Invitation $item
                $state.EmailAddress = $state.Body.invitedUserEmailAddress
                $pending.Add($state)
            } catch {
                $results.Add((New-GraphEssentialsInvitationResult -State $state -Status Failed -ErrorCode 'InvalidInvitation' -ErrorMessage $_.Exception.Message))
            }
        }
        $submitted = $false
        if ($pending.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess("$($pending.Count) invitation(s)", 'Submit Microsoft Graph invitation batch')) {
                if (-not $connection) {
                    $context = Get-MgContext -ErrorAction Stop
                    if (-not $context -or -not $context.TenantId) {
                        throw 'Connect-MgGraph before submitting invitations.'
                    }
                    $connection = [pscustomobject] @{
                        TenantId    = $context.TenantId
                        ClientId    = $context.ClientId
                        Account     = $context.Account
                        AuthType    = $context.AuthType
                        Environment = $context.Environment
                    }
                }
                $completed = @(Invoke-GraphEssentialsInvitationBatch -Pending $pending.ToArray() -Connection $connection -MaxRetries $MaxRetries -MaxRetryDelaySeconds $MaxRetryDelaySeconds -PendingBatchAction $PendingBatchAction)
                foreach ($result in $completed) {
                    $results.Add($result)
                }
                $submitted = $true
            } else {
                $status = if ($WhatIfPreference) { 'WhatIf' } else { 'Skipped' }
                foreach ($state in $pending) {
                    $results.Add((New-GraphEssentialsInvitationResult -State $state -Status $status))
                }
            }
        }
        $ordered = @($results | Sort-Object -Property InputIndex)
        if ($submitted -and $ResultBatchAction) {
            $null = & $ResultBatchAction ([object[]] $ordered)
        }
        $ordered
    }
}
