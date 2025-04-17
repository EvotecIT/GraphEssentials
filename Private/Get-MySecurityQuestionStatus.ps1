function Get-MySecurityQuestionStatus {
    [CmdletBinding()]
    param()

    $securityQuestionLookup = [System.Collections.Concurrent.ConcurrentDictionary[string, bool]]::new()
    Write-Verbose "Get-MySecurityQuestionStatus: Starting fetch for ALL user registration details (for Security Question status) using Invoke-MgGraphRequest..."
    Write-Warning "Get-MySecurityQuestionStatus: Fetching all user registration details can be time-consuming and memory-intensive for large tenants."

    try {
        # Use Invoke-MgGraphRequest and handle pagination manually
        $allRegistrationDetails = [System.Collections.Generic.List[object]]::new()
        $uri = '/beta/reports/authenticationMethods/userRegistrationDetails?$select=id,methodsRegistered,IsAdmin&$top=999' # Start with $top=999
        $pageCount = 0

        do {
            $pageCount++
            Write-Verbose "Get-MySecurityQuestionStatus: Fetching page $pageCount from URI: $uri"
            $response = Invoke-MgGraphRequest -Method Get -Uri $uri -ErrorAction Stop

            if ($response -and $response.value) {
                Write-Verbose "Get-MySecurityQuestionStatus: Received $($response.value.Count) records on page $pageCount."
                $allRegistrationDetails.AddRange($response.value)
            } else {
                Write-Verbose "Get-MySecurityQuestionStatus: No records found on page $pageCount."
            }

            # Get the next link
            $uri = $response.'@odata.nextLink'

        } while ($uri)


        if ($allRegistrationDetails.Count -gt 0) {
            Write-Verbose "Get-MySecurityQuestionStatus: Processing $($allRegistrationDetails.Count) total user registration records..."
            foreach ($userDetail in $allRegistrationDetails) {
                if (-not $userDetail.Id) { continue }
                # Ensure methodsRegistered is treated as an array even if it's null or single value
                $methodsRegisteredArray = @($userDetail.methodsRegistered)
                $isRegistered = $methodsRegisteredArray -contains 'securityQuestion'
                $securityQuestionLookup[$userDetail.Id] = $isRegistered
            }
        } else {
            Write-Warning "Get-MySecurityQuestionStatus: No user registration details returned after pagination."
        }

    } catch {
        Write-Error "Get-MySecurityQuestionStatus: Failed to retrieve user registration details using Invoke-MgGraphRequest. Error: $($_.Exception.Message) ErrorRecord: $($_.ToString()) StackTrace: $($_.ScriptStackTrace)"
        # Return an empty lookup table on failure
        return [System.Collections.Concurrent.ConcurrentDictionary[string, bool]]::new()
    }

    Write-Verbose "Get-MySecurityQuestionStatus: Finished processing security question status."
    return $securityQuestionLookup
}

function Get-MySecurityQuestionStatusOld {
    <#
    .SYNOPSIS
    Short description

    .DESCRIPTION
    Long description

    .EXAMPLE
    An example

    .NOTES

    Id                                            : 584069be-9349-4de5-a634-ca34ca48a010
    IsAdmin                                       :
    IsMfaCapable                                  :
    IsMfaRegistered                               :
    IsPasswordlessCapable                         :
    IsSsprCapable                                 :
    IsSsprEnabled                                 :
    IsSsprRegistered                              :
    IsSystemPreferredAuthenticationMethodEnabled  :
    LastUpdatedDateTime                           :
    MethodsRegistered                             : {}
    SystemPreferredAuthenticationMethods          :
    UserDisplayName                               :
    UserPreferredMethodForSecondaryAuthentication :
    UserPrincipalName                             :
    UserType                                      :
    AdditionalProperties                          : {}

    Id                                            : 6b45ee05-6dcf-47f7-933c-a8d433c9afd4
    IsAdmin                                       :
    IsMfaCapable                                  :
    IsMfaRegistered                               :
    IsPasswordlessCapable                         :
    IsSsprCapable                                 :
    IsSsprEnabled                                 :
    IsSsprRegistered                              :
    IsSystemPreferredAuthenticationMethodEnabled  :
    LastUpdatedDateTime                           :
    MethodsRegistered                             : {mobilePhone, microsoftAuthenticatorPush, softwareOneTimePasscode}
    SystemPreferredAuthenticationMethods          :
    UserDisplayName                               :
    UserPreferredMethodForSecondaryAuthentication :
    UserPrincipalName                             :
    UserType                                      :
    AdditionalProperties                          : {}

    #>
    [CmdletBinding()]
    param()

    $securityQuestionLookup = [System.Collections.Concurrent.ConcurrentDictionary[string, bool]]::new()
    Write-Verbose "Get-MySecurityQuestionStatus: Starting fetch for ALL user registration details (for Security Question status)..."
    Write-Warning "Get-MySecurityQuestionStatus: Fetching all user registration details can be time-consuming and memory-intensive for large tenants."

    try {
        # Fetch all details, selecting only necessary properties
        # Consider adding -Top if memory becomes an issue, but that would miss users
        $allRegistrationDetails = Get-MgReportAuthenticationMethodUserRegistrationDetail -All -Property 'id,methodsRegistered' -ErrorAction Stop

        if ($allRegistrationDetails) {
            Write-Verbose "Get-MySecurityQuestionStatus: Processing $($allRegistrationDetails.Count) user registration records..."
            foreach ($userDetail in $allRegistrationDetails) {
                if (-not $userDetail.Id) { continue }
                $isRegistered = $userDetail.methodsRegistered -contains 'securityQuestion'
                $securityQuestionLookup[$userDetail.Id] = $isRegistered
            }
        } else {
            Write-Warning "Get-MySecurityQuestionStatus: No user registration details returned."
        }

    } catch {
        Write-Error "Get-MySecurityQuestionStatus: Failed to retrieve user registration details. Error: $($_.Exception.Message) ErrorRecord: $($_.ToString()) StackTrace: $($_.ScriptStackTrace)"
        # Return an empty lookup table on failure
        return [System.Collections.Concurrent.ConcurrentDictionary[string, bool]]::new()
    }

    Write-Verbose "Get-MySecurityQuestionStatus: Finished processing security question status."
    return $securityQuestionLookup
}

