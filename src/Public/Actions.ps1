function New-HookAction
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string[]]
        $PostAction
    )

    $Name = $Name.Trim()

    # ensure action doesn't already exist
    if (Test-HookAction -Name $Name) {
        throw "Action with name '$($Name)' already exists"
    }

    # ensure the post actions exist
    $PostAction | ForEach-Object {
        if (![string]::IsNullOrWhiteSpace($_) -and !(Test-HookAction -Name $_)) {
            throw "Action with name '$($_)' does not exist"
        }
    }

    # add action
    $HookContext.Actions[$Name] = @{
        Name = $Name
        ScriptBlock = $ScriptBlock
        Actions = $PostAction
    }
}