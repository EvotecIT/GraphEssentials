function ConvertTo-GraphEssentialsInvitationBody {
    <# Validate an invitation record before dispatch; parse CSV Boolean text rather than casting nonempty strings. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Invitation)

    $email = [string] (Get-GraphEssentialsObjectValue -InputObject $Invitation -Name 'EmailAddress')
    if ([string]::IsNullOrWhiteSpace($email)) {
        throw 'EmailAddress is required.'
    }
    $email = $email.Trim()
    $address = [System.Net.Mail.MailAddress]::new($email)
    if ($address.Address -ne $email) {
        throw 'EmailAddress must contain only the address, without a display name.'
    }
    $redirect = [string] (Get-GraphEssentialsObjectValue -InputObject $Invitation -Name 'InviteRedirectUrl')
    if ([string]::IsNullOrWhiteSpace($redirect)) {
        $redirect = 'https://myapps.microsoft.com'
    }
    $uri = $null
    if (-not [uri]::TryCreate($redirect, [UriKind]::Absolute, [ref] $uri) -or $uri.Scheme -notin @('http', 'https')) {
        throw 'InviteRedirectUrl must be an absolute HTTP or HTTPS URL.'
    }
    $body = @{
        invitedUserEmailAddress = $email
        inviteRedirectUrl       = $redirect
    }
    foreach ($name in @('SendInvitationMessage', 'ResetRedemption')) {
        $value = Get-GraphEssentialsObjectValue -InputObject $Invitation -Name $name
        $boolean = $false
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string] $value)) {
            if (-not [bool]::TryParse(([string] $value).Trim(), [ref] $boolean)) {
                throw "$name must be True or False."
            }
        }
        $body[$name.Substring(0, 1).ToLowerInvariant() + $name.Substring(1)] = $boolean
    }
    $displayName = [string] (Get-GraphEssentialsObjectValue -InputObject $Invitation -Name 'DisplayName')
    if ($displayName) {
        $body.invitedUserDisplayName = $displayName
    }
    $userType = [string] (Get-GraphEssentialsObjectValue -InputObject $Invitation -Name 'UserType')
    if ($userType) {
        if ($userType -notin @('Member', 'Guest')) {
            throw 'UserType must be Member or Guest.'
        }
        $body.invitedUserType = $userType
    }
    $userId = [string] (Get-GraphEssentialsObjectValue -InputObject $Invitation -Name 'InvitedUserId')
    if ($body.resetRedemption -and -not $userId) {
        throw 'ResetRedemption requires the existing InvitedUserId.'
    }
    if ($userId) {
        $id = [guid] $userId
        if ($id -eq [guid]::Empty) {
            throw 'InvitedUserId must be a nonempty user object ID.'
        }
        $body.invitedUser = @{ id = $id.ToString('D') }
    }
    $body
}
