# Hook

A cross-platform PowerShell module for creating async hooks on events, and triggering associated actions when the event has fired.

## Example

### Clock

The following will create a new Trigger to return the current time, when the time/minute changes the associated Action is invoked - the Action will show a notification via the BurntToast module.

```powershell
# use BurntToast for the pop-up
Import-Module -Name BurntToast

# create an Action to show pop-up of time
# the $Result parameter is supplied by Hook, and contains the Data that caused the event to Trigger
New-HookAction -Name ToastOutput -ScriptBlock {
    param($Result)
    New-BurntToastNotification -Text "Time Check", $Result.Data -Sound IM
}

# create a new trigger to get the current time
New-HookTrigger -Name TimeCheck -ScriptBlock {
    return (Get-Date).ToString('dd-MM-yyyy HH:mm')
}

# register the event to happen every 10secs, and associate the above Action with it
# -Observe here means the event will trigger only of the data (the datetime) changes,
# and not to fire every 10secs!
Register-HookEvent -Trigger TimeCheck -Observe -Interval 10 -Action ToastOutput
```

Then to start monitoring, save the above script as `./events.ps1`, and in PowerShell run:

```powershell
Start-Hook ./events.ps1
```

You should now get a pop-up once a minute.

## Services

What if you want to monitor a service, and want to be sent an email if the service stops and see a pop-up? Let's say you want to check the MongoDB service:

```powershell
# use BurntToast for the pop-up
Import-Module -Name BurntToast

# create an Action to show pop-up when service stops
# the $Result parameter is supplied by Hook, and contains the Data that caused the event to Trigger - in this case, it would be the service object
New-HookAction -Name ToastOutput -ScriptBlock {
    param($Result)
    New-BurntToastNotification -Text "Service Stopped", "The $($Result.Data.Name) service has stopped!"
}

# create an Action to send an email, if the service stops
New-HookAction -Name SendEmail -ScriptBlock {
    param($Result)

    $prms = @{
        To = 'joe.bloggs@example.com'
        From = 'server@cloud.com'
        Body = "The MongoDB service has stopped!"
        Subject = "The MongoDB service has stopped!"
        SmtpServer = 'localhost'
    }

    Send-MailMessage @prms
}

# register an event, but this time use the inbuilt trigger for "Get-Service".
# this event will monitor the MongoDB service, and will only produce data if the service stops.
# it will check the service every 60secs, and will only trigger -Once, and not for every minute the service is stopped
Register-HookEvent `
    -Trigger _.Windows.Services `
    -Arguments @{ Name = 'MongoDB' } `
    -Filter { $_.Status -ine 'Running' } `
    -Once `
    -Interval 60 `
    -Action SendEmail, ToastOutput
```

Then to start monitoring, save the above script as `./events.ps1`, and in PowerShell run:

```powershell
Start-Hook ./events.ps1
```

## Notes

A trigger will only fire when it produces data. The `-Once` and `-Observe` switches on `Register-HookEvent` will only invoke any actions if it's the first time the trigger has fired after not being fired, or if the data changes.

Without these switches, the trigger will fire every time it produces data. So in the case of the Clock example above, with `-Observe` the trigger would fire every 10secs. If instead you changed it to `-Once` then you would get one pop-up for the time, and then never again.
