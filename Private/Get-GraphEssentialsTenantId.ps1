function Get-GraphEssentialsTenantId {
    param()

    Write-Verbose "Get-GraphEssentialsTenantId: Fetching Tenant ID..."
    $TenantId = $null
    try {
        $TenantId = (Get-MgContext -ErrorAction Stop).TenantId
        if ($TenantId) {
            Write-Verbose "Get-GraphEssentialsTenantId: Tenant ID found: $TenantId"
        } else {
             Write-Warning "Get-GraphEssentialsTenantId: Could not determine Tenant ID from context."
        }
    } catch {
        Write-Warning "Get-GraphEssentialsTenantId: Error getting MgContext. Ensure you are connected. Error: $($_.Exception.Message)"
    }
    return $TenantId
}