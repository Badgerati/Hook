function Test-HookAction
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    return $HookContext.Actions.ContainsKey($Name.Trim())
}