function Format-GraphEssentialsOwnerString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject] $OwnerResolved
    )

    $dispName = $OwnerResolved.DisplayName
    $upn = $OwnerResolved.UserPrincipalName
    $mail = $OwnerResolved.Mail
    $id = $OwnerResolved.Id
    $oDataType = $OwnerResolved.ODataType
    $appId = $OwnerResolved.AppId

    $ownerString = $null
    if ($dispName) { $ownerString = $dispName }

    if ($upn) {
        $ownerString = if ($ownerString) { "$ownerString <$upn>" } else { $upn }
    } elseif ($mail) {
        $ownerString = if ($ownerString) { "$ownerString <$mail>" } else { $mail }
    }

    if (-not $ownerString -and $oDataType) { $ownerString = $oDataType }
    if (-not $ownerString -and $id)       { $ownerString = $id }
    if (-not $ownerString)                { $ownerString = "(Unknown owner)" }

    # Append type shorthand if present
    if ($oDataType) {
        $typeShort = $oDataType.Split('.')[-1].Trim('#')
        if ($typeShort -eq 'servicePrincipal' -and $appId) {
            $ownerString += " ($typeShort, $appId)"
        } else {
            $ownerString += " ($typeShort)"
        }
    }
    return $ownerString
}
