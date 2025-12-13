function Get-GraphEssentialsErrorDetails {
    <#
    .SYNOPSIS
    Extracts detailed error information from Microsoft Graph API error responses.

    .DESCRIPTION
    Parses error responses from Microsoft Graph API calls to extract structured error
    details including error codes and messages. Handles various formats of error responses
    and provides standardized error output.

    .PARAMETER ErrorRecord
     The PowerShell ErrorRecord object containing the error information.
    .PARAMETER FunctionName
        Optional. The name of the function where the error occurred. Used in warning messages.
        Default is 'GraphEssentials'.
    .EXAMPLE
        try {
            Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
        } catch {
            $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Get-MyGraphData'
            Write-Warning $errorInfo.Message
        }
    .OUTPUTS
        [PSCustomObject] with error details including Code, Message, and FullMessage.
    .NOTES
        Requires Microsoft.Graph PowerShell modules.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(Mandatory = $false)]
        [string]$FunctionName = 'GraphEssentials'
    )


    # Create the default return object
    $errorDetails = [PSCustomObject]@{
        Code = 'Unknown'
        Message = 'Unknown error'
        FullMessage = ''
        IsGraphError = $false
        Original = $null
    }

    # Store the original error
    $errorDetails.Original = $ErrorRecord

    try {
        # First attempt to extract error details from Graph API JSON response
        if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
            # Extract just the error JSON part from the message
            # Look specifically for the error JSON object at the end of the message
            if ($ErrorRecord.ErrorDetails.Message -match '({"\s*error"\s*:.+})$') {
                $jsonContent = $Matches[1]
                $errorResponse = $jsonContent | ConvertFrom-Json -ErrorAction Stop

                if ($errorResponse.error) {
                    # We found a proper Graph API error response
                    $errorDetails.Code = $errorResponse.error.code
                    $errorDetails.Message = $errorResponse.error.message
                    $errorDetails.IsGraphError = $true

                    # Create a standardized full error message
                    $errorDetails.FullMessage = "$($FunctionName): Graph API Error - Code: $($errorResponse.error.code), Message: $($errorResponse.error.message)"

                    # Special handling for known error types
                    if ($errorResponse.error.code -like '*Authorization*') {
                        $errorDetails.FullMessage += "`n$($FunctionName): This may indicate insufficient permissions. Check if you have the required permissions."
                    }
                    elseif ($errorResponse.error.code -eq 'BadRequest') {
                        $errorDetails.FullMessage += "`n$($FunctionName): This may indicate invalid query parameters or property names."
                    }

                    # Return early since we found what we needed
                    return $errorDetails
                }
            }
        }

        # If we couldn't get details from ErrorDetails.Message, try other approaches
        if ($ErrorRecord.Exception.Response) {
            # Try to get status code and description from the response
            $statusCode = [int]$ErrorRecord.Exception.Response.StatusCode
            $statusDesc = $ErrorRecord.Exception.Response.StatusDescription

            $errorDetails.Code = "HTTP $statusCode"
            $errorDetails.Message = "HTTP $statusCode $statusDesc"
            $errorDetails.FullMessage = "$($FunctionName): Failed with HTTP status $statusCode $statusDesc"
        }
        elseif ($ErrorRecord.Exception.Message) {
            # Use the exception message if available
            $errorDetails.Message = $ErrorRecord.Exception.Message
            $errorDetails.FullMessage = "$($FunctionName): $($ErrorRecord.Exception.Message)"
        }

        # Check specifically for permission errors in the exception string
        $exceptionText = $ErrorRecord.Exception.ToString()
        if ($exceptionText -like '*Authorization_RequestDenied*' -or
            $exceptionText -like '*Forbidden*' -or
            $exceptionText -like '*Insufficient privileges*' -or
            $exceptionText -like '*insufficient*permission*' -or
            $exceptionText -like '*permission*denied*' -or
            $exceptionText -like '*accessDenied*') {
            $errorDetails.FullMessage += "`n$($FunctionName): This often indicates insufficient permissions."
        }
    }
    catch {
        # If our error parsing throws an error, return a simple message with the original error text
        $errorDetails.FullMessage = "$($FunctionName): Error occurred. Original error: $($ErrorRecord.Exception.Message)"
    }

    $errorDetails
}
