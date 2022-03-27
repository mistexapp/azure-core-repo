<#
    Project Name: Battery
    Version: 1
#>


$project = "Battery"    #Folder, Registry etc.
$time = 840               #15m
$ErrorActionPreference = "Continue"

function  start_project{

    function IsValNull ($v) {
        if ($v -is [system.array]) {
            $v = $v[0]
        }
        if (-not ($v)) {
            $v = 'Undefined'
        }
        if ($v -cmatch '[^\x20-\x7F]'){
            $v = 'Undefined'
        }
        [string]$v
    }

    function islaptop{
        Param( [string]$computer = "localhost" )
        $isLaptop = $false
        if(Get-WmiObject -Class win32_systemenclosure -ComputerName $computer | Where-Object { $_.chassistypes -eq 9 -or $_.chassistypes -eq 10 -or $_.chassistypes -eq 14})
        {
            $isLaptop = $true
        }
        $isLaptop
    }

    if(islaptop) {
        $BattAssembly = [Windows.Devices.Power.Battery,Windows.Devices.Power.Battery,ContentType=WindowsRuntime]
        try {
            $Report = [Windows.Devices.Power.Battery]::AggregateBattery.GetReport()
            if ($Report.Status -ne "NotPresents"){
                $pbmax = [convert]::ToDouble($Report.FullChargeCapacityInMilliwattHours)
                $pbvalue = [convert]::ToDouble($Report.RemainingCapacityInMilliwattHours)
                $battery_capacity = [int][math]::Round( (($pbvalue / $pbmax) *100))
                $battery_charging = ($Report.Status  | Out-String).Trim()
                if ($battery_charging -eq 'Idle') { 
                    $battery_charging = 'Discharging' 
                }
            } else {
                $battery_charging = 'Undefined'
                $battery_capacity = 0.0001
            }
        } catch {
            $battery_charging = 'Undefined'
            $battery_capacity = 0.0001
        }
    } else {
        $battery_charging = 'No batteries'
        $battery_capacity=100
    }

    $obj = [PSCustomObject]@{
        serialnumber = IsValNull $_check.serial_number
        batt_charging = IsValNull $battery_charging
        batt_capacity = IsValNull $batt_capacity
    }
    . "$PSScriptRoot\_send.ps1"
    _send $project $obj
}

. "$PSScriptRoot\_check.ps1"
try{
    $_check = _check $time $project
    $script_path = $_check.script_path
    $logfile = "$script_path\$project.log"

    Start-Transcript -path $logfile -Append:$false | Out-Null

    if (($_check.start) -and ($_check.start -eq 1)) {
        if ( ((Get-WmiObject Win32_OperatingSystem).CSName) -notlike '*srv*') {
            Write-Host "Started: ", $_check.raw_time -ForegroundColor DarkGray
            start_project
            Write-Host "Finished: ", ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now,"Russian Standard Time")) -ForegroundColor DarkYellow
            exit 0
        }
    } else {
        Write-Host "Exit." -ForegroundColor Red
        try{
            stop-transcript|out-null
        } catch [System.InvalidOperationException]{}
    }
    
} catch {
    Write-Host "Can't check script info"
    Write-Host $_
    try{
        stop-transcript|out-null
    } catch [System.InvalidOperationException]{}
}  