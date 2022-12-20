Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Application.ReadWrite.All

Show-MyApp -FilePath $PSScriptRoot\Reports\Applications.html -Show