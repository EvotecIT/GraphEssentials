function Get-MyTeam {
    [cmdletbinding()]
    param(
        [switch] $PerOwner,
        [switch] $AsHashtable
    )

    $OwnerShip = [ordered] @{}
    try {
        $Url = "https://graph.microsoft.com/beta/teams"
        $Teams = Do {
            $TeamsRaw = Invoke-MgGraphRequest -Method GET -Uri $Url -ContentType 'application/json; charset=UTF-8' -ErrorAction Stop
            if ($TeamsRaw.value) {
                $TeamsRaw.value
            }
            if ($TeamsRaw."@odata.nextLink") {
                $Url = $TeamsRaw."@odata.nextLink"
            }
        } While ($null -ne $TeamsRaw."@odata.nextLink")
    } catch {
        Write-Warning -Message "Get-MyTeam - Couldn't get list of teams. Error: $($_.Exception.Message)"
        return
    }
    foreach ($Team in $Teams) {
        try {
            $Owner = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$($Team.id)/owners" -ContentType 'application/json; charset=UTF-8' -ErrorAction Stop
        } catch {
            Write-Warning -Message "Get-MyTeam - Couldn't get list of owners. Error: $($_.Exception.Message)"
            return
        }
        try {
            $TeamDetails = Get-MgTeam -TeamId $Team.id -ErrorAction Stop
        } catch {
            Write-Warning -Message "Get-MyTeam - Error: $($_.Exception.Message)"
            return
        }

        $TeamInformation = [ordered] @{
            Id                                = $Team.id
            CreatedDateTime                   = $TeamDetails.createdDateTime
            Team                              = $Team.displayName
            Visibility                        = $Team.visibility
            OwnerCount                        = $Owner.value.Count
            MembersCount                      = $TeamDetails.Summary.MembersCount
            GuestsCount                       = $TeamDetails.Summary.GuestsCount

            Description                       = $Team.description
            OwnerDisplayName                  = $Owner.value.displayName
            OwnerMail                         = $Owner.value.mail
            OwnerUserPrincipalName            = $Owner.value.userPrincipalName
            OwnerId                           = $Owner.value.id
            IsArchived                        = $Team.isArchived

            GuestAllowCreateUpdateChannels    = $TeamDetails.GuestSettings.AllowCreateUpdateChannels
            GuestAllowDeleteChannels          = $TeamDetails.GuestSettings.AllowDeleteChannels

            AllowAddRemoveApps                = $TeamDetails.MemberSettings.AllowAddRemoveApps
            AllowCreatePrivateChannels        = $TeamDetails.MemberSettings.AllowCreatePrivateChannels
            AllowCreateUpdateChannels         = $TeamDetails.MemberSettings.AllowCreateUpdateChannels
            AllowCreateUpdateRemoveConnectors = $TeamDetails.MemberSettings.AllowCreateUpdateRemoveConnectors
            AllowCreateUpdateRemoveTabs       = $TeamDetails.MemberSettings.AllowCreateUpdateRemoveTabs
            AllowDeleteChannels               = $TeamDetails.MemberSettings.AllowDeleteChannels
            IsMembershipLimitedToOwners       = $TeamDetails.MemberSettings.isMembershipLimitedToOwners
        }
        if ($PerOwner) {
            foreach ($O in $Owner.value) {
                if (-not $OwnerShip[$O.userPrincipalName]) {
                    $OwnerShip[$O.userPrincipalName] = [System.Collections.Generic.List[PSCustomObject]]::new()
                }
                if ($AsHashtable) {
                    $OwnerShip[$O.userPrincipalName].Add($TeamInformation)
                } else {
                    $OwnerShip[$O.userPrincipalName].Add([PSCustomObject]$TeamInformation)
                }
            }
        } else {
            if ($AsHashtable) {
                $TeamInformation
            } else {
                [PSCustomObject]$TeamInformation
            }
        }
    }
    if ($PerOwner) {
        $OwnerShip
    }
}