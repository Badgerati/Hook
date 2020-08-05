function Register-HookEvent
{
    [CmdletBinding(DefaultParameterSetName='Default')]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Trigger,

        [Parameter()]
        [scriptblock]
        $Filter,

        [Parameter()]
        [int]
        $Interval = 30,

        [Parameter()]
        [hashtable]
        $Arguments,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Action,

        [Parameter(ParameterSetName='Once')]
        [switch]
        $Once, # only trigger once

        [Parameter(ParameterSetName='Observe')]
        [switch]
        $Observe # only trigger if the result count changes
    )

    # set variables
    $Trigger = $Trigger.Trim()

    if ($Interval -le 9) {
        $Interval = 10
    }

    if (($null -eq $Arguments) -or ($Arguments.Count -eq 0)) {
        $Arguments = @{}
    }

    # ensure trigger exists
    if (!(Test-HookTrigger -Name $Trigger)) {
        throw "Trigger '$($Trigger)' does not exist"
    }

    # ensure the actions exist
    $Action | ForEach-Object {
        if (!(Test-HookAction -Name $_)) {
            throw "Action with name '$($_)' does not exist"
        }
    }

    # add trigger
    $HookContext.Events += @{
        Type = $Trigger
        Filter = $Filter
        Actions = $Action
        ScriptBlock = $HookContext.Triggers[$Trigger]
        Arguments = $Arguments
        Interval = $Interval
        Once = $Once
        Observe = $Observe
        Triggered = $false
        PreviousResult = $null
        NextTriggerTime = [datetime]::UtcNow.AddSeconds($Interval)
    }
}

function New-HookTrigger
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [scriptblock]
        $ScriptBlock
    )

    $Name = $Name.Trim()

    # ensure the the trigger doesn't already exist
    if (Test-HookTrigger -Name $Name) {
        throw "Trigger '$($Name)' already exists"
    }

    # add custom trigger
    $HookContext.Triggers[$Name] = $ScriptBlock
}