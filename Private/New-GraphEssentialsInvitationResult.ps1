function New-GraphEssentialsInvitationResult {
    <# Produce the same per-input outcome shape for local validation, simulation and remote responses. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $State,
        [Parameter(Mandatory)][ValidateSet('Succeeded', 'Failed', 'Uncertain', 'Deferred', 'WhatIf', 'Skipped')][string] $Status,
        [int] $StatusCode,
        [long] $RetryAfterSeconds,
        $Invitation,
        [string] $ErrorCode,
        [string] $ErrorMessage
    )

    [pscustomobject] @{
        InputIndex             = $State.InputIndex
        Context                = $State.Context
        EmailAddress           = $State.EmailAddress
        Status                 = $Status
        Success                = $Status -eq 'Succeeded'
        RequiresReconciliation = $Status -eq 'Uncertain'
        StatusCode             = $StatusCode
        AttemptCount           = $State.AttemptCount
        RetryDelaySeconds      = $State.RetryDelaySeconds
        RetryAfterSeconds      = $RetryAfterSeconds
        RequestId              = $State.RequestId
        InvitedUserId          = if ($Invitation) {
            $user = Get-GraphEssentialsObjectValue -InputObject $Invitation -Name 'InvitedUser'
            Get-GraphEssentialsObjectValue -InputObject $user -Name 'Id'
        } else {
            $null
        }
        Invitation             = $Invitation
        ErrorCode              = $ErrorCode
        ErrorMessage           = $ErrorMessage
    }
}
