Import-Module -Name BurntToast

New-HookAction -Name ConsoleOutput -ScriptBlock {
    param($Result)

    if ($Result.Data.Count -eq 1) {
        New-BurntToastNotification -Text 'MongoDB is running!' -Sound Default
    }
    else {
        New-BurntToastNotification -Text 'MongoDB has stopped!' -Sound IM
    }
}

Register-HookEvent `
    -Trigger _.Windows.Services `
    -Arguments @{ Name = 'MongoDB' } `
    -Filter { $_.Status -ieq 'Running' } `
    -Observe `
    -Interval 5 `
    -Action ConsoleOutput






New-HookAction -Name ToastOutput -ScriptBlock {
    param($Result)
    New-BurntToastNotification -Text "Time Check", $Result.Data -Sound IM
}

New-HookTrigger -Name 'TimeCheck' -ScriptBlock {
    return (Get-Date).ToString('dd-MM-yyyy HH:mm')
}

Register-HookEvent -Trigger TimeCheck -Observe -Interval 10 -Action ToastOutput
