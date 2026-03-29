function Get-MyTeam {
    <#
    .SYNOPSIS
    Retrieves Teams information from Microsoft Graph API.

    .DESCRIPTION
    Gets detailed information about Microsoft Teams including team membership, owner information,
    and team settings. Can organize information by team owner and optionally return as a hashtable.

    .PARAMETER PerOwner
    When specified, organizes the output by team owner instead of by team.

    .PARAMETER AsHashtable
    When specified, returns data as a hashtable instead of objects.

    .EXAMPLE
    Get-MyTeam
    Returns a list of all Teams with their properties.

    .EXAMPLE
    Get-MyTeam -PerOwner
    Returns Teams organized by owner.

    .EXAMPLE
    Get-MyTeam -AsHashtable
    Returns Teams information as a hashtable for easier programmatic access.

    .NOTES
    This function requires the Microsoft.Graph.Teams module and appropriate permissions.
    #>
    [CmdletBinding()]
    param(
        [switch] $PerOwner,
        [switch] $AsHashtable
    )

    $Today = Get-Date
    $OwnerShip = [ordered] @{}

    try {
        $Teams = Get-MgTeam -All -ErrorAction Stop
    } catch {
        Write-Warning -Message "Get-MyTeam - Couldn't get list of teams. Error: $($_.Exception.Message)"
        return
    }

    foreach ($Team in $Teams) {
        try {
            $TeamDetails = Get-MgTeam -TeamId $Team.Id -Property DisplayName, Description, CreatedDateTime, GuestSettings, MemberSettings -ExpandProperty Summary -ErrorAction Stop
            $Owner = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/teams/$($Team.Id)/owners" -ContentType 'application/json; charset=UTF-8' -ErrorAction Stop
        } catch {
            Write-Warning -Message "Get-MyTeam - Error (extended) on team $($Team.DisplayName) / $($Team.Id): $($_.Exception.Message)"
            continue
        }

        if ($TeamDetails.CreatedDateTime) {
            $CreatedDaysAgo = [math]::Floor((New-TimeSpan -Start $TeamDetails.CreatedDateTime -End $Today).TotalDays)
        } else {
            $CreatedDaysAgo = $null
        }

        $HasOwners = $Owner.value.Count -gt 0
        $HasMultipleOwners = $Owner.value.Count -gt 1
        $HasGuests = $TeamDetails.Summary.GuestsCount -gt 0
        $GuestControlsEnabled = $TeamDetails.GuestSettings.AllowCreateUpdateChannels -or $TeamDetails.GuestSettings.AllowDeleteChannels

        $TeamInformation = [ordered] @{
            Id                                = $Team.Id
            CreatedDateTime                   = $TeamDetails.CreatedDateTime
            CreatedDaysAgo                    = $CreatedDaysAgo
            Team                              = $Team.DisplayName
            Visibility                        = $Team.Visibility
            IsPublic                          = $Team.Visibility -eq 'Public'
            IsPrivate                         = $Team.Visibility -eq 'Private'
            OwnerCount                        = $Owner.value.Count
            HasOwners                         = $HasOwners
            HasMultipleOwners                 = $HasMultipleOwners
            MembersCount                      = $TeamDetails.Summary.MembersCount
            GuestsCount                       = $TeamDetails.Summary.GuestsCount
            HasGuests                         = $HasGuests
            Description                       = $Team.Description
            OwnerDisplayName                  = $Owner.value.DisplayName
            OwnerMail                         = $Owner.value.Mail
            OwnerUserPrincipalName            = $Owner.value.UserPrincipalName
            OwnerId                           = $Owner.value.Id
            GuestAllowCreateUpdateChannels    = $TeamDetails.GuestSettings.AllowCreateUpdateChannels
            GuestAllowDeleteChannels          = $TeamDetails.GuestSettings.AllowDeleteChannels
            GuestControlsEnabled              = $GuestControlsEnabled
            AllowAddRemoveApps                = $TeamDetails.MemberSettings.AllowAddRemoveApps
            AllowCreatePrivateChannels        = $TeamDetails.MemberSettings.AllowCreatePrivateChannels
            AllowCreateUpdateChannels         = $TeamDetails.MemberSettings.AllowCreateUpdateChannels
            AllowCreateUpdateRemoveConnectors = $TeamDetails.MemberSettings.AllowCreateUpdateRemoveConnectors
            AllowCreateUpdateRemoveTabs       = $TeamDetails.MemberSettings.AllowCreateUpdateRemoveTabs
            AllowDeleteChannels               = $TeamDetails.MemberSettings.AllowDeleteChannels
        }

        if ($PerOwner) {
            foreach ($O in $Owner.value) {
                if (-not $OwnerShip[$O.UserPrincipalName]) {
                    $OwnerShip[$O.UserPrincipalName] = [System.Collections.Generic.List[PSCustomObject]]::new()
                }
                if ($AsHashtable) {
                    $OwnerShip[$O.UserPrincipalName].Add($TeamInformation)
                } else {
                    $OwnerShip[$O.UserPrincipalName].Add([PSCustomObject] $TeamInformation)
                }
            }
        } else {
            if ($AsHashtable) {
                $TeamInformation
            } else {
                [PSCustomObject] $TeamInformation
            }
        }
    }

    if ($PerOwner) {
        $OwnerShip
    }
}
