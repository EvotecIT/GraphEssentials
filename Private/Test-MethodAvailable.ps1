function Test-MethodAvailable {
    param([string]$Id)
    return $availableIdsLower -contains $Id.ToLower()
}