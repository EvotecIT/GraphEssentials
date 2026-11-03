function Write-MyAppCertificateSessionEvent {
    <# Accept only bounded, public metadata; never forward configuration or provider exceptions. #>
    [CmdletBinding()]
    param([string] $Event, [string] $Message, [hashtable] $Data = @{}, [scriptblock] $OnEvent)
    $record = [pscustomobject] @{ Event = $Event; Message = $Message; Data = $Data }
    if ($OnEvent) { & $OnEvent $record | Out-Null }
    else { Write-Information "[$Event] $Message" -InformationAction Continue }
}
