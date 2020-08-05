function New-HookRunspaceState
{
    $state = [initialsessionstate]::CreateDefault()

    $variables = @(
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'HookContext', $HookContext, $null),
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'Console', $Host, $null),
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'HOOK_SCOPE_RUNSPACE', $true, $null)
    )

    foreach ($var in $variables) {
        $state.Variables.Add($var)
    }

    (Get-Module | Where-Object { ($_.ModuleType -ieq 'script') }).Name |
        Sort-Object -Unique |
        ForEach-Object {
            $_path = (Get-Module -Name $_ |
                Sort-Object -Property Version -Descending |
                Select-Object -First 1 -ExpandProperty Path)

            $state.ImportPSModule($_path)
        }

    return $state
}

function New-HookRunspacePool
{
    $state = New-HookRunspaceState
    $HookContext.Runspaces.Pool = [runspacefactory]::CreateRunspacePool(1, 10, $state, $Host)
}

function Start-HookScheduler
{
    $script = {
        while ($true)
        {
            $_now = [DateTime]::Now

            # only run events have a next trigger in the past
            $HookContext.Events | Where-Object {
                $_.NextTriggerTime -le $_now
            } | ForEach-Object {
                Invoke-HookTrigger -Trigger $_
                $_.NextTriggerTime = $_now.AddSeconds($_.Interval)
            }

            Start-Sleep -Seconds 1
        }
    }

    Add-HookRunspace -ScriptBlock $script
}

function Invoke-HookTrigger
{
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Trigger
    )

    $script = Get-HookTriggerScheduleScript
    Add-HookRunspace -ScriptBlock $script -Parameters @{ Trigger = $Trigger } -Forget
}