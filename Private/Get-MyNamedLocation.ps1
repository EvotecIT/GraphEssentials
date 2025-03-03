function Get-MyNamedLocation {
    <#
    .SYNOPSIS
    Retrieves named locations from Microsoft Graph.

    .DESCRIPTION
    Gets detailed information about named locations configured in Azure AD/Entra ID,
    which are used in conditional access policies to define trusted networks or geographic areas.
    Returns both IP-based and country/region-based location configurations.

    .PARAMETER Type
    Filters results by location type. Valid values are 'IP' for IP-based locations and 'CountryRegion' for country/region-based locations.

    .EXAMPLE
    Get-MyNamedLocation
    Returns all named locations from Microsoft Graph.

    .EXAMPLE
    Get-MyNamedLocation -Type IP
    Returns only IP-based named locations.

    .NOTES
    This function requires the Microsoft.Graph.Identity.SignIns module and appropriate permissions.
    Typically requires Policy.Read.All permission.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('IP', 'CountryRegion')]
        [string] $Type
    )

    try {
        Write-Verbose -Message "Get-MyNamedLocation - Getting named locations from Microsoft Graph"
        if ($Type) {
            $NamedLocations = Get-MgIdentityConditionalAccessNamedLocation -All -Filter "LocationType eq '$Type'" -ErrorAction Stop
            Write-Verbose -Message "Get-MyNamedLocation - Retrieved $($NamedLocations.Count) named locations of type '$Type'"
        } else {
            $NamedLocations = Get-MgIdentityConditionalAccessNamedLocation -All -ErrorAction Stop
            Write-Verbose -Message "Get-MyNamedLocation - Retrieved $($NamedLocations.Count) named locations"
        }
    } catch {
        Write-Warning -Message "Get-MyNamedLocation - Failed to get named locations. Error: $($_.Exception.Message)"
        return
    }

    foreach ($Location in $NamedLocations) {
        if ($Location.AdditionalProperties.oDataType -eq '#microsoft.graph.ipNamedLocation') {
            # Process IP-based named location
            [PSCustomObject]@{
                Id                                = $Location.Id
                DisplayName                       = $Location.DisplayName
                CreatedDateTime                   = $Location.CreatedDateTime
                ModifiedDateTime                  = $Location.ModifiedDateTime
                Type                              = 'IP'
                IsTrusted                         = $Location.AdditionalProperties.isTrusted
                IpRanges                          = $Location.AdditionalProperties.ipRanges.cidrAddress -join ', '
                RawIpRanges                       = $Location.AdditionalProperties.ipRanges.cidrAddress
                RangeCount                        = $Location.AdditionalProperties.ipRanges.Count
                IncludeUnknownCountriesAndRegions = $null
                CountriesAndRegions               = $null
                RawCountriesAndRegions            = $null
                CountryCount                      = $null
            }
        } elseif ($Location.AdditionalProperties.oDataType -eq '#microsoft.graph.countryNamedLocation') {
            # Process country/region-based named location
            [PSCustomObject]@{
                Id                                = $Location.Id
                DisplayName                       = $Location.DisplayName
                CreatedDateTime                   = $Location.CreatedDateTime
                ModifiedDateTime                  = $Location.ModifiedDateTime
                Type                              = 'CountryRegion'
                IsTrusted                         = $null
                IpRanges                          = $null
                RawIpRanges                       = $null
                RangeCount                        = $null
                IncludeUnknownCountriesAndRegions = $Location.AdditionalProperties.includeUnknownCountriesAndRegions
                CountriesAndRegions               = $Location.AdditionalProperties.countriesAndRegions -join ', '
                RawCountriesAndRegions            = $Location.AdditionalProperties.countriesAndRegions
                CountryCount                      = $Location.AdditionalProperties.countriesAndRegions.Count
            }
        } else {
            # Handle any other type of named location that might be introduced in the future
            Write-Warning -Message "Get-MyNamedLocation - Unknown location type: $($Location.AdditionalProperties.oDataType) for location $($Location.DisplayName)"

            [PSCustomObject]@{
                Id                                = $Location.Id
                DisplayName                       = $Location.DisplayName
                CreatedDateTime                   = $Location.CreatedDateTime
                ModifiedDateTime                  = $Location.ModifiedDateTime
                Type                              = $Location.AdditionalProperties.oDataType.Replace('#microsoft.graph.', '')
                IsTrusted                         = $null
                IpRanges                          = $null
                RawIpRanges                       = $null
                RangeCount                        = $null
                IncludeUnknownCountriesAndRegions = $null
                CountriesAndRegions               = $null
                RawCountriesAndRegions            = $null
                CountryCount                      = $null
                AdditionalProperties              = $Location.AdditionalProperties
            }
        }
    }
}