function Start-Hook
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $FilePath,

        [switch]
        $NoWait
    )

    if ($null -ne (Get-Variable -Name HookContext -Scope Global -ErrorAction Ignore)) {
        Remove-Variable -Name HookContext -Scope Global -Force
    }

    # create initial context
    New-Variable -Name HookContext -Scope Global -Value @{
        Events = @()
        Triggers = @{}
        Actions = @{}
        Runspaces = @{
            Pool = $null
            Threads = @()
        }
    }

    Set-HookInbuiltTriggers

    # set it so ctrl-c can terminate
    if (!$NoWait) {
        [Console]::TreatControlCAsInput = $true
    }

    # load the script
    $script = Get-Content -Path $FilePath -Raw -Force -ErrorAction Stop
    $script = [scriptblock]::Create($script)
    & $script.GetNewClosure()

    # fail if there are no events
    if (($null -eq $HookContext.Events) -or ($HookContext.Events.Length -eq 0)) {
        throw "No events have been registered"
    }

    try {
        # create the trigger runspace pool
        New-HookRunspacePool
        $HookContext.Runspaces.Pool.Open()

        # start the scheduler
        Start-HookScheduler

        # are we listening?
        $msg = "Listening on $($HookContext.Events.Length) events(s)"
        if (!$NoWait) {
            $msg += ' [Ctrl-C to stop]'
        }

        Write-Host $msg -ForegroundColor Yellow

        # if we're not waiting, return
        if ($NoWait) {
            return
        }

        # otherwise, wait for termination
        while (!(Test-HookTerminationPressed -Key $key)) {
            Start-Sleep -Seconds 1
            $key = Get-HookConsoleKey
        }

        Write-Host 'Terminating...' -NoNewline -ForegroundColor Yellow
    }
    finally {
        if (!$NoWait) {
            $HookContext.Runspaces.Threads | Where-Object { !$_.Stopped } | ForEach-Object {
                $_.Runspace.Dispose()
                $_.Stopped = $true
            }

            $HookContext.Runspaces.Pool.Dispose()
            Remove-Variable -Name HookContext -Scope Global -Force
            Write-Host " Done" -ForegroundColor Green
        }
    }
}