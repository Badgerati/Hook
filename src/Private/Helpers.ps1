function Add-HookRunspace
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        $Parameters = $null,

        [switch]
        $Forget
    )

    try
    {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $HookContext.Runspaces.Pool
        $ps.AddScript($ScriptBlock) | Out-Null

        if ($null -ne $Parameters) {
            $Parameters.Keys | ForEach-Object {
                $ps.AddParameter($_, $Parameters[$_]) | Out-Null
            }
        }

        if ($Forget) {
            $ps.BeginInvoke() | Out-Null
        }
        else {
            $HookContext.Runspaces.Threads += @{
                Runspace = $ps
                Status = $ps.BeginInvoke()
                Stopped = $false
            }
        }
    }
    catch {
        throw $_.Exception
    }
}

function Test-HookTerminationPressed
{
    param(
        [Parameter()]
        $Key = $null
    )

    return (Test-HookKeyPressed -Key $Key -Character 'c')
}

function Test-HookKeyPressed
{
    param(
        [Parameter()]
        $Key = $null,

        [Parameter(Mandatory=$true)]
        [string]
        $Character
    )

    if ($null -eq $Key) {
        $Key = Get-HookConsoleKey
    }

    return (($null -ne $Key) -and ($Key.Key -ieq $Character) -and
        (($Key.Modifiers -band [ConsoleModifiers]::Control) -or (($PSVersionTable.Platform -ieq 'unix') -and ($Key.Modifiers -band [ConsoleModifiers]::Shift))))
}

function Get-HookConsoleKey
{
    if ([Console]::IsInputRedirected -or ![Console]::KeyAvailable) {
        return $null
    }

    return [Console]::ReadKey($true)
}

function Test-HookIsWindowsPwsh
{
    return ($PSVersionTable.PSVersion.Major -le 5)
}

function Read-HookWebExceptionDetails
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    $body = $ErrorRecord.Exception.Message

    if ($body -imatch '(No such host is known|The remote name could not be resolved)') {
        $code = 404
        $desc = 'Not Found'
        $headers = $null
    }
    elseif ($body -imatch '(The operation was canceled|The operation has timed out)') {
        $code = 500
        $desc = 'Timeout'
        $headers = $null
    }
    else {
        switch ($ErrorRecord) {
            { $_.Exception -is [System.Net.WebException] } {
                $stream = $_.Exception.Response.GetResponseStream()
                $stream.Position = 0

                $body = [System.IO.StreamReader]::new($stream).ReadToEnd()
                $code = [int]$_.Exception.Response.StatusCode
                $desc = [string]$_.Exception.Response.StatusDescription
                $headers = $_.Exception.Response.Headers.ToString()
            }

            { $_.Exception -is [System.Net.Http.HttpRequestException] } {
                $code = [int]$_.Exception.Response.StatusCode
                $desc = [string]$_.Exception.Response.ReasonPhrase
                $headers = ($_.Exception.Response.Headers.ToString() + $_.Exception.Response.Content.Headers.ToString())
            }
        }
    }

    # if headers, parse them as hashtable
    $c_headers = $null
    if ($null -ne $headers) {
        $c_headers = [ordered]@{}

        ($headers -isplit [System.Environment]::NewLine) | ForEach-Object {
            $parts = ($_ -isplit ':')
            $key = $parts[0].Trim()
            $value = ($parts[1..($parts.Length - 1)] -join '').Trim()

            if (!$c_headers.ContainsKey($key)) {
                $c_headers.Add($key, @())
            }

            $c_headers[$key] += $value
        }
    }

    return [ordered]@{
        StatusCode = $code
        StatusDescription = $desc
        Content = $body
        Headers = $c_headers
    }
}