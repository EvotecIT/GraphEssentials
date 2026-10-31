function Assert-MyAppCertificateRotationContext {
    <# Keep ordinary maintenance within the authenticated application; reconciliation uses read-only administration. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $State,
        [switch] $Reconcile
    )

    $context = Get-MgContext -ErrorAction Stop
    if (-not $context -or [string] $context.TenantId -ne [string] $State.TenantId -or $context.Environment -ne 'Global') {
        throw 'Connect to the profile tenant in the Microsoft public cloud before certificate maintenance.'
    }
    if (-not $Reconcile -and ($context.AuthType -ne 'AppOnly' -or [string] $context.ClientId -ne [string] $State.ClientId)) {
        throw 'Certificate self-rotation requires an app-only Graph connection for the enrolled client ID.'
    }
}
