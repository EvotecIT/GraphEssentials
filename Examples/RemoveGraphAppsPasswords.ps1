Import-Module graphessentials -Force

Connect-MgGraph -Scopes Application.ReadWrite.All

$AppNames = @(
    'MS-Teams-Communications-Spoke'
)
$WhatIf = $true

return

$Applications = foreach ($App in $AppNames) {
    Get-MyApp -ApplicationName $App
}
$Applications | Format-Table *

return

$ApplicationsPasswordExpired = foreach ($App in $AppNames) {
    Get-MyAppCredentials -ApplicationName $App -Expired
    Remove-MyAppCredentials -Verbose -ApplicationName $App -Expired -WhatIf:$WhatIf
    Remove-MyAppCredentials -Verbose -ApplicationName $App -DisplayNameCredentials "O:*" -WhatIf:$WhatIf
}
$ApplicationsPasswordExpired | Format-Table *

