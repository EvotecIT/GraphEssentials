function Get-MyTeam {
    <#
    .SYNOPSIS
    Retrieves Teams information from Microsoft Graph API.

    .DESCRIPTION
    Gets detailed information about Microsoft Teams including team membership, owner information,
    and team settings. Can organize information by team owner and optionally return as a hashtable.

    .PARAMETER PerOwner
    When specified, organizes the output by team owner instead of by team. Teams with no owner
    are returned under [No owner], while teams whose owner state could not be read are returned
    under [Owner state unavailable].

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
    This function requires the Microsoft.Graph.Teams and Microsoft.Graph.Groups modules.
    Reading team settings typically requires TeamSettings.Read.All. Reading owners requires
    GroupMember.Read.All or another permission that can read Microsoft 365 group owners.
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
        $TeamDetails = $null
        try {
            $TeamDetails = Get-MgTeam -TeamId $Team.Id -Property DisplayName, Description, CreatedDateTime, GuestSettings, MemberSettings, Summary -ErrorAction Stop
        } catch {
            Write-Warning -Message "Get-MyTeam - Couldn't get extended details for team $($Team.DisplayName) / $($Team.Id): $($_.Exception.Message)"
        }

        $Owners = @()
        $OwnersRetrieved = $false
        try {
            $Owners = @(
                foreach ($Owner in @(Get-MgGroupOwner -GroupId $Team.Id -All -ErrorAction Stop)) {
                    $AdditionalProperties = $Owner.AdditionalProperties
                    $DisplayName = $Owner.DisplayName
                    $Mail = $Owner.Mail
                    $UserPrincipalName = $Owner.UserPrincipalName
                    if ($AdditionalProperties) {
                        if (-not $DisplayName) {
                            $DisplayName = $AdditionalProperties['displayName']
                        }
                        if (-not $Mail) {
                            $Mail = $AdditionalProperties['mail']
                        }
                        if (-not $UserPrincipalName) {
                            $UserPrincipalName = $AdditionalProperties['userPrincipalName']
                        }
                    }

                    [PSCustomObject] @{
                        DisplayName       = $DisplayName
                        Mail              = $Mail
                        UserPrincipalName = $UserPrincipalName
                        Id                = $Owner.Id
                    }
                }
            )
            $OwnersRetrieved = $true
        } catch {
            Write-Warning -Message "Get-MyTeam - Couldn't get owners for team $($Team.DisplayName) / $($Team.Id): $($_.Exception.Message)"
        }

        if ($TeamDetails.CreatedDateTime) {
            $CreatedDaysAgo = [math]::Floor((New-TimeSpan -Start $TeamDetails.CreatedDateTime -End $Today).TotalDays)
        } else {
            $CreatedDaysAgo = $null
        }

        if ($OwnersRetrieved) {
            $OwnerCount = $Owners.Count
            $HasOwners = $OwnerCount -gt 0
            $HasMultipleOwners = $OwnerCount -gt 1
        } else {
            $OwnerCount = $null
            $HasOwners = $null
            $HasMultipleOwners = $null
        }
        if ($null -ne $TeamDetails -and $null -ne $TeamDetails.Summary -and $null -ne $TeamDetails.Summary.GuestsCount) {
            $HasGuests = $TeamDetails.Summary.GuestsCount -gt 0
        } else {
            $HasGuests = $null
        }
        if ($null -ne $TeamDetails -and $null -ne $TeamDetails.GuestSettings) {
            $GuestAllowCreateUpdateChannels = $TeamDetails.GuestSettings.AllowCreateUpdateChannels
            $GuestAllowDeleteChannels = $TeamDetails.GuestSettings.AllowDeleteChannels
            if ($GuestAllowCreateUpdateChannels -eq $true -or $GuestAllowDeleteChannels -eq $true) {
                $GuestControlsEnabled = $true
            } elseif ($null -ne $GuestAllowCreateUpdateChannels -and $null -ne $GuestAllowDeleteChannels) {
                $GuestControlsEnabled = $false
            } else {
                $GuestControlsEnabled = $null
            }
        } else {
            $GuestAllowCreateUpdateChannels = $null
            $GuestAllowDeleteChannels = $null
            $GuestControlsEnabled = $null
        }
        if ($null -ne $Team.Visibility) {
            $IsPublic = $Team.Visibility -eq 'Public'
            $IsPrivate = $Team.Visibility -eq 'Private'
        } else {
            $IsPublic = $null
            $IsPrivate = $null
        }

        $TeamInformation = [ordered] @{
            Id                                = $Team.Id
            CreatedDateTime                   = $TeamDetails.CreatedDateTime
            CreatedDaysAgo                    = $CreatedDaysAgo
            Team                              = $Team.DisplayName
            Visibility                        = $Team.Visibility
            IsPublic                          = $IsPublic
            IsPrivate                         = $IsPrivate
            OwnerCount                        = $OwnerCount
            HasOwners                         = $HasOwners
            HasMultipleOwners                 = $HasMultipleOwners
            MembersCount                      = $TeamDetails.Summary.MembersCount
            GuestsCount                       = $TeamDetails.Summary.GuestsCount
            HasGuests                         = $HasGuests
            Description                       = $Team.Description
            OwnerDisplayName                  = $Owners.DisplayName
            OwnerMail                         = $Owners.Mail
            OwnerUserPrincipalName            = $Owners.UserPrincipalName
            OwnerId                           = $Owners.Id
            GuestAllowCreateUpdateChannels    = $GuestAllowCreateUpdateChannels
            GuestAllowDeleteChannels          = $GuestAllowDeleteChannels
            GuestControlsEnabled              = $GuestControlsEnabled
            AllowAddRemoveApps                = $TeamDetails.MemberSettings.AllowAddRemoveApps
            AllowCreatePrivateChannels        = $TeamDetails.MemberSettings.AllowCreatePrivateChannels
            AllowCreateUpdateChannels         = $TeamDetails.MemberSettings.AllowCreateUpdateChannels
            AllowCreateUpdateRemoveConnectors = $TeamDetails.MemberSettings.AllowCreateUpdateRemoveConnectors
            AllowCreateUpdateRemoveTabs       = $TeamDetails.MemberSettings.AllowCreateUpdateRemoveTabs
            AllowDeleteChannels               = $TeamDetails.MemberSettings.AllowDeleteChannels
        }

        if ($PerOwner) {
            foreach ($Owner in $Owners) {
                $OwnerKey = $Owner.UserPrincipalName
                if (-not $OwnerKey) {
                    $OwnerKey = $Owner.Mail
                }
                if (-not $OwnerKey) {
                    $OwnerKey = $Owner.Id
                }
                if (-not $OwnerKey) {
                    Write-Warning -Message "Get-MyTeam - Owner without a usable identity on team $($Team.DisplayName) / $($Team.Id) was skipped."
                    continue
                }

                if (-not $OwnerShip[$OwnerKey]) {
                    $OwnerShip[$OwnerKey] = [System.Collections.Generic.List[PSCustomObject]]::new()
                }
                if ($AsHashtable) {
                    $OwnerShip[$OwnerKey].Add($TeamInformation)
                } else {
                    $OwnerShip[$OwnerKey].Add([PSCustomObject] $TeamInformation)
                }
            }
            if ($Owners.Count -eq 0) {
                $OwnerKey = if ($OwnersRetrieved) { '[No owner]' } else { '[Owner state unavailable]' }
                if (-not $OwnerShip[$OwnerKey]) {
                    $OwnerShip[$OwnerKey] = [System.Collections.Generic.List[PSCustomObject]]::new()
                }
                if ($AsHashtable) {
                    $OwnerShip[$OwnerKey].Add($TeamInformation)
                } else {
                    $OwnerShip[$OwnerKey].Add([PSCustomObject] $TeamInformation)
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
