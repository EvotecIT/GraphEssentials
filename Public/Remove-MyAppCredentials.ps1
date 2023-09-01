function Remove-MyAppCredentials {
    [cmdletBinding(SupportsShouldProcess)]
    param(
        [string] $ApplicationName,
        [int] $LessThanDaysToExpire,
        [int] $GreaterThanDaysToExpire,
        [switch] $Expired,
        [alias('DescriptionCredentials')][string] $DisplayNameCredentials
    )

    $getMyAppCredentialsSplat = @{}
    if ($PSBoundParameters.ContainsKey('ApplicationName')) {
        $getMyAppCredentialsSplat.ApplicationName = $ApplicationName
    }
    if ($PSBoundParameters.ContainsKey('LessThanDaysToExpire')) {
        $getMyAppCredentialsSplat.LessThanDaysToExpire = $LessThanDaysToExpire
    }
    if ($PSBoundParameters.ContainsKey('Expired')) {
        $getMyAppCredentialsSplat.Expired = $Expired
    }
    if ($PSBoundParameters.ContainsKey('DisplayNameCredentials')) {
        $getMyAppCredentialsSplat.DisplayNameCredentials = $DisplayNameCredentials
    }
    if ($PSBoundParameters.ContainsKey('GreaterThanDaysToExpire')) {
        $getMyAppCredentialsSplat.GreaterThanDaysToExpire = $GreaterThanDaysToExpire
    }
    $Applications = Get-MyAppCredentials @getMyAppCredentialsSplat
    foreach ($App in $Applications) {
        Write-Verbose -Message "Processing application $($App.ApplicationName) for key removal $($App.KeyDisplayName)/$($App.KeyId) - Start: $($App.StartDateTime), End: $($App.EndDateTime), IsExpired: $($App.Expired)"
        if ($PSCmdlet.ShouldProcess($App.ApplicationName, "Remove $($App.KeyDisplayName)/$($App.KeyId)")) {
            try {
                # it has it's own whatif, but it looks ugly
                Remove-MgApplicationPassword -ApplicationId $App.ObjectID -KeyId $App.KeyId -ErrorAction Stop
            } catch {
                Write-Warning -Message "Failed to remove $($App.KeyDisplayName)/$($App.KeyId) from $($App.ApplicationName). Error: $($_.Exception.Message)"
            }
        }
    }
}