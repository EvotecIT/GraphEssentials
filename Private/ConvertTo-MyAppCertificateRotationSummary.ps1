function ConvertTo-MyAppCertificateRotationSummary {
    <# Project an allow-list of safe profile fields; private PFX records never escape through ordinary output. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $State,
        [Parameter(Mandatory)][string] $Path,
        [string] $Action = 'Inspect'
    )

    [pscustomobject] @{
        Path                   = $Path
        TenantId               = $State.TenantId
        ClientId               = $State.ClientId
        ApplicationObjectId    = $State.ApplicationObjectId
        Phase                  = $State.Phase
        Action                 = $Action
        ActiveKeyId            = $State.Active.KeyId
        ActiveThumbprint       = $State.Active.Thumbprint
        ActiveExpiresOn        = [datetimeoffset] $State.Active.NotAfterUtc
        RenewAfterUtc          = ([datetimeoffset] $State.Active.NotAfterUtc).AddSeconds(-$State.Policy.RenewBeforeSeconds)
        RetireAfterUtc         = $State.RetireAfterUtc
        RequiresReconciliation = $State.Phase -in @('Registering', 'Retiring')
        LastCompletedAtUtc     = $State.LastCompletedAtUtc
    }
}
