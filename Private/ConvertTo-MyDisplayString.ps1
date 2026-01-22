function ConvertTo-MyDisplayString {
    <#
    .SYNOPSIS
    Converts values to readable strings for HTML reporting.

    .DESCRIPTION
    Formats strings, arrays, and dictionaries into readable strings using line breaks
    so PSWriteHTML can render multi-line values cleanly.

    .PARAMETER Value
    The value to convert into a display string.

    .PARAMETER ReturnEmptyStringForNull
    When specified, returns an empty string instead of $null for null input.

    .PARAMETER LineSeparator
    Separator used between lines when formatting arrays or dictionaries.

    .PARAMETER InlineSeparator
    Separator used for inline values such as nested collections.

    .EXAMPLE
    ConvertTo-MyDisplayString -Value $Value

    Returns a readable string for use in HTML tables.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)][AllowNull()] $Value,
        [switch] $ReturnEmptyStringForNull,
        [string] $LineSeparator = "`r`n",
        [string] $InlineSeparator = ', '
    )

    if ($null -eq $Value) {
        if ($ReturnEmptyStringForNull) {
            return ''
        }
        return $null
    }

    if ($Value -is [string]) {
        $Normalized = $Value -replace '<br\\s*/?>', $LineSeparator
        return $Normalized.Trim()
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $Pairs = [System.Collections.Generic.List[string]]::new()
        foreach ($Key in $Value.Keys) {
            $ItemValue = ConvertTo-MyDisplayString -Value $Value[$Key] -ReturnEmptyStringForNull -LineSeparator $LineSeparator -InlineSeparator $InlineSeparator
            if ($ItemValue) {
                $ItemValue = $ItemValue -replace [regex]::Escape($LineSeparator), $InlineSeparator
            }
            $Pairs.Add("${Key}=$ItemValue")
        }
        return ($Pairs -join $LineSeparator).Trim()
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        $Items = [System.Collections.Generic.List[string]]::new()
        foreach ($Item in $Value) {
            if ($null -ne $Item) {
                $ItemValue = ConvertTo-MyDisplayString -Value $Item -ReturnEmptyStringForNull -LineSeparator $LineSeparator -InlineSeparator $InlineSeparator
                if ($ItemValue) {
                    $ItemValue = $ItemValue -replace [regex]::Escape($LineSeparator), $InlineSeparator
                    $Items.Add($ItemValue)
                }
            }
        }
        return ($Items -join $LineSeparator).Trim()
    }

    $Result = [string]$Value
    $Result = $Result -replace '<br\\s*/?>', $LineSeparator
    return $Result.Trim()
}
