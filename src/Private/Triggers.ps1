function Get-HookTriggerScheduleScript
{
    return {
        param($Trigger)

        try {
            # run the trigger
            $result = (& $Trigger.ScriptBlock.GetNewClosure() $Trigger.Arguments)
            if ($null -ne $Trigger.Filter) {
                $result = ($result | Where-Object $Trigger.Filter)
            }

            # get previous result, and then update it
            $previousResult = $Trigger.PreviousResult
            $Trigger.PreviousResult = $result

            # if we're observing, and the results haven't changed, return
            if ($Trigger.Observe -and (Compare-HookTriggerResult -NewResult $result -OldResult $previousResult)) {
                $Trigger.Triggered = $false
                return
            }

            # if there are no results (unless we're observing), return
            if (!$Trigger.Observe -and (Test-HookTriggerResultEmpty -Result $result)) {
                $Trigger.Triggered = $false
                return
            }

            # we've triggered, but are we only triggering once?
            if ($Trigger.Triggered -and $Trigger.Once) {
                return
            }

            $Trigger.Triggered = $true

            # the event object
            $parameters = @{
                Trigger = $Trigger.Type
                Result = @{
                    Data = $result
                }
            }

            # keep a queue of the actions
            $queue = [System.Collections.Queue]::new()
            $Trigger.Actions | ForEach-Object { $queue.Enqueue($_) }

            while (($queue.Count -gt 0) -and ($null -ne ($actionName = $queue.Dequeue()))) {
                $action = $HookContext.Actions[$actionName]
                (& $action.ScriptBlock @parameters) | Out-Null
                $action.Actions | ForEach-Object { $queue.Enqueue($_) }
            }
        }
        catch {
            $_.Exception | Out-Default
            $_.ScriptStackTrace | Out-Default
            throw $_.Exception
        }
    }
}

# Return true if they're the same, false otherwise
function Compare-HookTriggerResult
{
    param(
        [Parameter()]
        $NewResult,

        [Parameter()]
        $OldResult
    )

    # are they both null?
    if (($null -eq $NewResult) -and ($null -eq $OldResult)) {
        return $true
    }

    # is one null, and the other not?
    if ((($null -eq $NewResult) -and ($null -ne $OldResult)) -or (($null -eq $OldResult) -and ($null -ne $NewResult))) {
        return $false
    }

    # are they different types?
    if ($NewResult.GetType() -ine $OldResult.GetType()) {
        return $false
    }

    # quick and dirty, are they just equal (if they aren't arrays)?
    if (($NewResult -isnot [array]) -and ($NewResult -ieq $OldResult)) {
        return $true
    }

    # if they're arrays, are their lengths the same?
    if (($NewResult -is [array]) -and ($NewResult.Length -eq $OldResult.Length)) {
        return $true
    }

    # if they're hashtable, are their counts the same?
    if (($NewResult -is [hashtable]) -and ($NewResult.Count -eq $OldResult.Count)) {
        return $true
    }

    # if they're a stirng or valuetype
    if (($NewResult -is [string]) -or ($NewResult -is [valuetype])) {
        return ($NewResult -ieq $OldResult)
    }

    # otherwise, check they're counts
    if (($NewResult | Measure-Object).Count -eq ($OldResult | Measure-Object).Count) {
        return $true
    }

    # otherwise, they aren't equal
    return $false
}

function Test-HookTriggerResultEmpty
{
    param(
        [Parameter()]
        $Result
    )

    # null
    if ($null -eq $Result) {
        return $true
    }

    # array
    if ($Result -is [array]) {
        return ($Result.Length -eq 0)
    }

    # hashtable
    if ($Result -is [hashtable]) {
        return ($Result.Count -eq 0)
    }

    # valuetype
    if ($Result -is [valuetype]) {
        if ($Result -is [bool]) {
            return !$Result
        }

        return ($Result -eq 0)
    }

    # string
    if ($Result -is [string]) {
        return [string]::IsNullOrEmpty($Result)
    }

    # default
    return (($Result | Measure-Object).Count -eq 0)
}

function Test-HookTrigger
{
    param(
        [Parameter()]
        [string]
        $Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    return $HookContext.Triggers.ContainsKey($Name)
}

function Set-HookInbuiltTriggers
{
    $HookContext.Triggers = @{
        '_.windows.services' =  {
            param([hashtable]$Arguments)
            Get-Service @Arguments
        }

        '_.windows.websites' = {
            param([hashtable]$Arguments)
            Get-Website @Arguments
        }

        '_.windows.event' = {
            param([hashtable]$Arguments)
            Get-EventLog @Arguments
        }

        '_.web.rest' = {
            param([hashtable]$Arguments)
            try {
                if (Test-HookIsWindowsPwsh) {
                    $Arguments['UseBasicParsing'] = $true
                }
                else {
                    $HookResponseHeaders = $null
                    $Arguments['ResponseHeadersVariable'] = 'HookResponseHeaders'
                }

                $success = $true
                $result = Invoke-RestMethod @Arguments
            }
            catch {
                $success = $false
                $result = Read-HookWebExceptionDetails -ErrorRecord $_
            }

            if ($success) {
                $result = [ordered]@{
                    StatusCode = 200
                    StatusDescription = 'OK'
                    Content = $result
                    Headers = [hashtable]$HookResponseHeaders
                }
            }
            else {
                $result = [ordered]@{
                    StatusCode = [int]$result.StatusCode
                    StatusDescription = [string]$result.StatusDescription
                    Content = [string]$result.Content
                    Headers = [hashtable]$result.Headers
                }
            }

            return $result
        }

        '_.web.request' = {
            param([hashtable]$Arguments)
            try {
                if (Test-HookIsWindowsPwsh) {
                    $Arguments['UseBasicParsing'] = $true
                }

                $result = Invoke-WebRequest @Arguments
            }
            catch {
                $result = Read-HookWebExceptionDetails -ErrorRecord $_
            }

            $result = [ordered]@{
                StatusCode = [int]$result.StatusCode
                StatusDescription = [string]$result.StatusDescription
                Content = [string]$result.Content
                Headers = [hashtable]$result.Headers
            }

            return $result
        }

        '_.remote.command' = {
            param([hashtable]$Arguments)
            Invoke-Command @Arguments
        }

        '_.clipboard' = {
            param([hashtable]$Arguments)
            Get-Clipboard @Arguments
        }

        '_.date' = {
            param([hashtable]$Arguments)
            Get-Date @Arguments
        }
    }
}