Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Application.ReadWrite.All, Mail.Send

# email information
$EmailFrom = 'przemyslaw.klys@test.pl'
$EmailTo = 'przemyslaw.klys@test.pl'

## app names
$AppNames = @(
    #@{ ApplicationName = '1sp-ct-knaufnow-prod'; Description = 'Management SP Knauf Now - Production'; ServicePrincipal = $true }
    #@{ ApplicationName = '1sp-ct-knaufnow-non-prod' ; Description = 'Management SP Knauf Now - Non Production'; ServicePrincipal = $true }
    #@{ ApplicationName = '1sp-ct-sandbox'; Description = 'Management SP for sandbox subscription'; ServicePrincipal = $true }
    'ServiceNow Intune Integration1'
)

$Output = Send-MyApp -EmailFrom $EmailFrom -EmailTo $EmailTo -ApplicationName $AppNames -Domain 'evotec.pl' -RemoveOldCredentials
$Output.EmailStatus | Format-Table
$Output.Applications | Format-Table