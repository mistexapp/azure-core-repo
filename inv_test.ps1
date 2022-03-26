<#
    Project Name: Inventory
    Version: 4
#>


$project = "IIInv"
$time = 10
$ErrorActionPreference = "Continue"

function  start_project{
    $myObject = Get-WmiObject -Class win32_operatingsystem
    $sn = $myObject | Select-Object -ExpandProperty 'SerialNumber'
    foreach ($name in (Get-WmiObject -Class win32_operatingsystem | Get-Member | Select-Object -ExpandProperty Name)) {
        if ([bool]($myObject.PSobject.Properties.name -match "$name")) {
            if (($name -notlike "FREE") -and ($name -notlike "*__*")){
                try {
                    $prop = (Get-WmiObject -Class win32_operatingsystem | Select-Object -ExpandProperty $name )
                } catch {
                    $_
                    $prop = 'Undefined'
                }
                if ($prop -eq '') {$prop = 'Undefined'}
                $timestamp = $_check.timestamp
                $to_send = 'tst,host={0} {1}="{2}" {3}' -f $sn, $name, $prop, $timestamp
                $to_send

                . "$PSScriptRoot\_send.ps1"
                _send $to_send
            }
        }
    }
}

. "$PSScriptRoot\_check.ps1"
try{
    $_check = _check $time $project
    $script_path = $_check.script_path
    $logfile = "$script_path\$project.log"

    Start-Transcript -path $logfile -Append:$false | Out-Null

    if (($_check.start) -and ($_check.start -eq 1)) {
        Write-Host "Started: ", $_check.raw_time -ForegroundColor DarkGray
        start_project
    } else {
        Write-Host "Exit." -ForegroundColor Red
        Stop-Transcript | Out-Null
        exit 1
    }
    
} catch {
    Write-Host "Can't check script info"
    Write-Host $_
    try {
        Stop-Transcript | Out-Null
    } catch {
        exit 1
    }
}