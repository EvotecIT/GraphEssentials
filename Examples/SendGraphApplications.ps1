Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Application.ReadWrite.All, Mail.Send

# email information
$EmailFrom = 'przemyslaw.klys@evotec.pl'
$EmailTo = 'przemyslaw.klys@evotec.pl'

## app names
$AppNames = @(
    #@{ ApplicationName = '1sp-ct-prod'; Description = 'Management SP Now - Production'; ServicePrincipal = $true }
    #@{ ApplicationName = '1sp-ct-non-prod' ; Description = 'Management SP Now - Non Production'; ServicePrincipal = $true }
    #@{ ApplicationName = '1sp-ct-sandbox'; Description = 'Management SP for sandbox subscription'; ServicePrincipal = $true }
    'ServiceNow Intune Integration1'
)

$Output = Send-MyApp -EmailFrom $EmailFrom -EmailTo $EmailTo -ApplicationName $AppNames -Domain 'evotec.pl' -RemoveOldCredentials
$Output.EmailStatus | Format-Table
$Output.Applications | Format-Table