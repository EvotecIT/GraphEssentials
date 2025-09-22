function New-MyAuthDetailRequests {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Users,

        [Parameter(Mandatory)]
        [System.Collections.Concurrent.ConcurrentDictionary[string, object]]$AllAuthMethods, # Summaries keyed by UserId

        # No longer mandatory
        [switch]$IncludeDeviceDetails
    )

    $detailRequestsList = [System.Collections.Generic.List[object]]::new() # List of request items for details
    $intermediateResults = @{} # Store intermediate data keyed by UserId
    Write-Verbose "New-MyAuthDetailRequests: Processing summaries and preparing detail requests..."

    foreach ($User in $Users) {
        $UserId = $User.Id
        if (-not $AllAuthMethods.ContainsKey($UserId)) {
            Write-Warning "New-MyAuthDetailRequests: Authentication methods summary data not found for $($User.UserPrincipalName) (User ID: $UserId). Skipping detail preparation."
            continue
        }
        $AuthMethods = $AllAuthMethods[$UserId]
        if ($null -eq $AuthMethods) {
            Write-Warning "New-MyAuthDetailRequests: Authentication methods summary fetch failed for $($User.UserPrincipalName) (User ID: $UserId). Skipping detail preparation."
            continue
        }

        $MethodTypes = $AuthMethods | ForEach-Object { $_.'@odata.type' -replace '#microsoft.graph.', '' }

        # Prepare requests for details needed for the second batch call
        foreach ($Method in $AuthMethods) {
            $methodType = $Method.'@odata.type'
            $methodId = $Method.id
            if (-not $methodId) { continue } # Skip if method has no ID

            # Determine if a detail request is needed and construct the URL
            $needsDetail = $false
            $detailUrl = $null
            switch ($methodType) {
                "#microsoft.graph.fido2AuthenticationMethod" {
                    if ($IncludeDeviceDetails) { $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/fido2Methods/$($methodId)" }
                }
                "#microsoft.graph.phoneAuthenticationMethod" {
                    $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/phoneMethods/$($methodId)"
                }
                "#microsoft.graph.emailAuthenticationMethod" {
                    $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/emailMethods/$($methodId)"
                }
                "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                    # Always fetch details (incl. device) for MS Auth App
                    $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/microsoftAuthenticatorMethods/$($methodId)?`$expand=device"
                }
                "#microsoft.graph.temporaryAccessPassAuthenticationMethod" {
                    $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/temporaryAccessPassMethods/$($methodId)"
                }
                "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                    if ($IncludeDeviceDetails) { $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/windowsHelloForBusinessMethods/$($methodId)?`$expand=device" }
                }
                "#microsoft.graph.softwareOathAuthenticationMethod" {
                    $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/softwareOathMethods/$($methodId)"
                }
                "#microsoft.graph.hardwareOathAuthenticationMethod" {
                    $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/hardwareOathMethods/$($methodId)"
                }
            }

            # Add to list if detail needed
            if ($needsDetail -and $detailUrl) {
                $requestId = "detail_$(($detailRequestsList.Count).ToString('X8'))" # Unique ID for detail requests
                $requestItem = @{ UserId = $UserId; MethodId = $methodId; RequestId = $requestId; MethodODataType = $methodType; BatchUrl = $detailUrl; Processed = $false; DetailData = $null }
                $detailRequestsList.Add($requestItem)
            }
        } # End foreach ($Method in $AuthMethods)

        # Store intermediate data needed for final object construction
        $intermediateResults[$UserId] = @{
            User        = $User
            AuthMethods = $AuthMethods # Store the summary methods
            MethodTypes = $MethodTypes
        }
    } # End foreach ($User in $Users)

    Write-Verbose "New-MyAuthDetailRequests: Finished processing summaries. Need to fetch $($detailRequestsList.Count) method details."

    # Return both results as a hashtable or PSCustomObject
    return [PSCustomObject]@{ # Indentation fixed
        DetailRequestsList  = $detailRequestsList
        IntermediateResults = $intermediateResults
    }
}
