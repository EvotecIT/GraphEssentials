function Resolve-GraphEssentialsOwner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject] $OwnerObject
    )

    $dispName = $null
    $upn = $null
    $mail = $null
    $oDataType = $null
    $id = $null
    $appId = $null

    if ($OwnerObject.PSObject.Properties['Id']) { $id = $OwnerObject.Id }
    if ($OwnerObject.PSObject.Properties['ODataType']) { $oDataType = $OwnerObject.ODataType }

    # AdditionalProperties (Graph SDK often puts most fields there)
    if ($OwnerObject.PSObject.Properties['AdditionalProperties']) {
        $ap = $OwnerObject.AdditionalProperties
        if ($ap) {
            if ($ap.ContainsKey('displayName')) { $dispName = $ap.displayName }
            if ($ap.ContainsKey('userPrincipalName')) { $upn = $ap.userPrincipalName }
            if ($ap.ContainsKey('mail')) { $mail = $ap.mail }
            if (-not $oDataType -and $ap.ContainsKey('@odata.type')) { $oDataType = $ap.'@odata.type' }
            if ($ap.ContainsKey('appId')) { $appId = $ap.appId }
            if (-not $id -and $ap.ContainsKey('id')) { $id = $ap.id }
        }
    }

    # Direct properties
    if (-not $dispName -and $OwnerObject.PSObject.Properties['DisplayName']) { $dispName = $OwnerObject.DisplayName }
    if (-not $upn -and $OwnerObject.PSObject.Properties['UserPrincipalName']) { $upn = $OwnerObject.UserPrincipalName }
    if (-not $mail -and $OwnerObject.PSObject.Properties['Mail']) { $mail = $OwnerObject.Mail }

    $permDenied = $false

    # If missing, try live lookups (user first, then service principal) using cached results
    if ($id) {
        if (-not $oDataType -and $OwnerObject.PSObject.Properties['@odata.type']) { $oDataType = $OwnerObject.'@odata.type' }

        # Try user lookup always when data missing
        if (-not $dispName -or -not $upn -or -not $mail) {
            try {
                if (-not $Script:GraphEssentialsOwnerCache) { $Script:GraphEssentialsOwnerCache = @{} }
                if (-not $Script:GraphEssentialsOwnerCache.ContainsKey($id)) {
                    $Script:GraphEssentialsOwnerCache[$id] = Get-MgUser -UserId $id -Property displayName,userPrincipalName,mail -ErrorAction Stop
                }
                $resolved = $Script:GraphEssentialsOwnerCache[$id]
                if ($resolved) {
                    if (-not $dispName -and $resolved.PSObject.Properties['DisplayName']) { $dispName = $resolved.DisplayName }
                    if (-not $upn -and $resolved.PSObject.Properties['UserPrincipalName']) { $upn = $resolved.UserPrincipalName }
                    if (-not $mail -and $resolved.PSObject.Properties['Mail']) { $mail = $resolved.Mail }
                    if (-not $oDataType) { $oDataType = '#microsoft.graph.user' }
                }
            } catch {
                # Note permission issue so we can surface a hint.
                $exceptionText = $_.Exception.ToString()
                if ($exceptionText -like '*Authorization_RequestDenied*' -or
                    $exceptionText -like '*Insufficient privileges*' -or
                    $exceptionText -like '*insufficient*permission*' -or
                    $exceptionText -like '*permission*denied*' -or
                    $exceptionText -like '*accessDenied*' -or
                    $exceptionText -like '*Forbidden*') {
                    $permDenied = $true
                }
            }
        }

        # Try service principal lookup if still nothing meaningful
        if (-not $dispName -or (-not $upn -and -not $mail) -or -not $appId) {
            try {
                if (-not $Script:GraphEssentialsOwnerSpCache) { $Script:GraphEssentialsOwnerSpCache = @{} }
                if (-not $Script:GraphEssentialsOwnerSpCache.ContainsKey($id)) {
                    $Script:GraphEssentialsOwnerSpCache[$id] = Get-MgServicePrincipal -ServicePrincipalId $id -Property displayName,appId -ErrorAction Stop
                }
                $spResolved = $Script:GraphEssentialsOwnerSpCache[$id]
                if ($spResolved) {
                    if (-not $dispName -and $spResolved.PSObject.Properties['DisplayName']) { $dispName = $spResolved.DisplayName }
                    if (-not $appId -and $spResolved.PSObject.Properties['AppId']) { $appId = $spResolved.AppId }
                    if (-not $oDataType) { $oDataType = '#microsoft.graph.servicePrincipal' }
                }
            } catch { }
        }
    }

    if ($permDenied -and (-not $dispName) -and (-not $upn) -and (-not $mail)) {
        $dispName = '(Permission Denied)'
        $oDataType = '#microsoft.graph.user'
        Write-Verbose 'Resolve-GraphEssentialsOwner: Permission missing: add User.Read.All or Directory.Read.All.'
    }

    [pscustomobject]@{
        Id                = $id
        ODataType         = $oDataType
        DisplayName       = $dispName
        UserPrincipalName = $upn
        Mail              = $mail
        AppId             = $appId
    }
}
