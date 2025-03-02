function Send-MyApp {
    <#
    .SYNOPSIS
    Creates application credentials and emails them to specified recipients.

    .DESCRIPTION
    Creates new Azure AD/Entra applications or adds credentials to existing applications,
    then sends the credentials securely via email to specified recipients. Optionally can
    remove old credentials during the process.

    .PARAMETER ApplicationName
    An array of application names to create or update. Can be strings or hashtables with configuration details.

    .PARAMETER EmailFrom
    The email address to send notifications from.

    .PARAMETER EmailTo
    One or more email addresses to send the credentials to.

    .PARAMETER EmailSubject
    The subject line for the email. Defaults to 'Service Principal for Applications'.

    .PARAMETER Domain
    The domain name of the tenant where applications are registered.

    .PARAMETER RemoveOldCredentials
    If specified, removes any existing credentials before adding new ones.

    .EXAMPLE
    Send-MyApp -ApplicationName "MyAPI" -EmailFrom "admin@contoso.com" -EmailTo "developer@contoso.com" -Domain "contoso.com"
    Creates or updates an application named "MyAPI" and emails the credentials to developer@contoso.com.

    .EXAMPLE
    Send-MyApp -ApplicationName @("API1", "API2") -EmailFrom "admin@contoso.com" -EmailTo "team@contoso.com" -Domain "contoso.com" -RemoveOldCredentials
    Creates or updates two applications, removes any existing credentials, and emails the new credentials to team@contoso.com.

    .NOTES
    This function requires the Microsoft.Graph.Applications module and appropriate permissions.
    Requires Application.ReadWrite.All permissions to create applications and credentials.
    #>
    [cmdletBinding()]
    param(
        [parameter(Mandatory)][Array] $ApplicationName,
        [parameter(Mandatory)][string] $EmailFrom,
        [parameter(Mandatory)][string[]] $EmailTo,
        [string] $EmailSubject = 'Service Principal for Applications',
        [parameter(Mandatory)][string] $Domain,
        [switch] $RemoveOldCredentials
    )

    $TenantID = Get-O365TenantID -Domain $Domain

    $Applications = foreach ($App in $ApplicationName) {
        if ($App -is [string]) {
            $DisplayNameCredentials = $EmailTo -join ";"
            New-MyApp -ApplicationName $App -DisplayNameCredentials $DisplayNameCredentials -Verbose -RemoveOldCredentials:$RemoveOldCredentials.IsPresent
        } else {
            if ($App.DisplayNameCredentials) {
                New-MyApp @App
            } else {
                $DisplayNameCredentials = $EmailTo -join ";"
                New-MyApp @App -DisplayNameCredentials $DisplayNameCredentials -Verbose -ServicePrincipal -RemoveOldCredentials:$RemoveOldCredentials.IsPresent
            }
        }
    }

    $EmailBody = EmailBody {
        EmailText -Text "Hello," -LineBreak
        EmailText -Text @(
            "As per your request we have created following Service Principal for you:"
        )
        EmailText -LineBreak

        foreach ($Application in $Applications) {
            EmailText -Text @(
                "Application ", $Application.ApplicationName, " credentials are: "
            ) -Color None, BlueDiamond, None -TextDecoration none, underline, none -FontWeight normal, bold, normal

            EmailList {
                EmailListItem -Text "Application Name: ", $Application.ApplicationName -Color None, BlueDiamond, None -FontWeight normal, bold, normal
                EmailListItem -Text "Client ID: ", $Application.ClientID -Color None, BlueDiamond, None -FontWeight normal, bold, normal
                EmailListItem -Text "Client SecretID: ", $Application.ClientSecretID -Color None, BlueDiamond, None -FontWeight normal, bold, normal
                EmailListItem -Text "Client Secret: ", $Application.ClientSecret -Color None, BlueDiamond, None -FontWeight normal, bold, normal
                EmailListItem -Text "Expires: ", $Application.EndDateTime, " (Valid days: $($Application.DaysToExpire))" -Color None, BlueDiamond, None -FontWeight normal, bold, normal
            }
        }
        EmailText -LineBreak

        EmailText -Text @(
            "If required TenantID/DirectoryID is: ", $TenantID
        ) -LineBreak -Color None, LawnGreen -FontWeight normal, bold

        EmailText -Text @(
            "Please remove this email from your inbox once you have copied the credentials into secure place."
        ) -FontWeight normal, normal, bold, normal, normal -Color None, None, Salmon, None, None -LineBreak

        EmailText -Text "Thank you"
    }

    $EmailStatus = Send-EmailMessage -From $EmailFrom -To $EmailTo -HTML $EmailBody -Subject $EmailSubject -Verbose -Priority Normal -MgGraphRequest

    [ordered] @{
        EmailStatus  = $EmailStatus
        Applications = $Applications
    }
}