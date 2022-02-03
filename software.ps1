$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | Out-Null

$project = 'Software'
$start_time = 840 #3540
$reg_path = "HKLM:\SOFTWARE\ITSupport\$project"
$script_path = "C:\Windows\System32\IntuneAdmins\$project"
$bucket = 'prod-db-sept'
$token = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "token").token
$url = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "url").url

if ($script_path | Test-Path){
    Remove-Item -Path $script_path -Recurse -Force -Confirm:$false | Out-Null
} else {
    New-Item -Path $script_path -Type Directory -force | Out-Null
}

$ErrorActionPreference = "Continue"
$logfile = "$script_path\$project.log"
Start-Transcript -path $logfile -Append:$false | Out-Null

#Delete old Software tasks
#_________________________________
Foreach ($x in ( Get-ScheduledTask | Select-Object TaskName)) {
    if ($x -like '*Software*'){
        $task_to_delete = $x | Select-Object -ExpandProperty TaskName
        Unregister-ScheduledTask -TaskName $task_to_delete -Confirm:$false
    }
}
#___________________________________________________________________________________________________________________________________________________________
$raw_time = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now,"Russian Standard Time")
$timestamp = ([DateTimeOffset]$raw_time).ToUnixTimeSeconds()
$raw_time

function RegistryValue($Path, $VarName, $VarValue) {
    if ($Path | Test-Path){
        try {
            Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $VarName -ErrorAction Stop | Out-Null
            if ($VarName -eq 'time'){
                $presented_value = (Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $VarName)
                if (!($presented_value -eq  $VarValue)){
                    New-ItemProperty -Path $Path -Name $VarName -Value $VarValue -Force | Out-Null
                    Write-Host "New time is: [$VarValue]" -ForegroundColor Yellow
                } else {
                    Write-Host "Time is the same [$VarValue]" -ForegroundColor Green
                }
            }
            elseif ($VarName -eq 'lastRequest'){
                $presented_value = (Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $VarName)
                $time = Get-ItemProperty -Path $Path | Select-Object -ExpandProperty time
                $delta = $VarValue - $presented_value
                if ($delta -ge  $time){
                    Write-Host "OK! DeltaTime is [$delta]. Starting..." -ForegroundColor Green
                    New-ItemProperty -Path $Path -Name $VarName -Value $VarValue -Force | Out-Null
                    sleep 1
                } else {
                    Write-Host "Passing. deltatime is [$delta] sec, but ExecuteTimeRange is [$time] sec." -ForegroundColor Red
                    exit 0
                }
            }
        }
        catch {
            Write-Host "[Path exist] -but- [$VarName[$VarValue]] was created." -ForegroundColor Magenta
            New-ItemProperty -Path $Path -Name $VarName -Value $VarValue -Force | Out-Null
        }
    } else {
        Write-Host "[$Path] -and- [$VarName[$VarValue]] were created." -ForegroundColor Magenta
        New-Item -Path $Path -force | Out-Null
        New-ItemProperty -Path $Path -Name $VarName -Value $VarValue -Force | Out-Null
    }
    
} 

RegistryValue "$reg_path\Settings" time $start_time
RegistryValue "$reg_path\Settings" lastRequest $timestamp

#___________________________________________________________________________________________________________________________________________________________
#Get App versions
$version_software = 2
$SerialNumber = (Get-WmiObject win32_bios | Select-Object -ExpandProperty serialnumber) -replace " "
$host_name = (Get-WmiObject Win32_OperatingSystem).CSName
if (($SerialNumber -like '*SystemSerialNumber*') -or ($SerialNumber -like '*Defaultstring*')) {
    $SerialNumber = "{0}-{1}" -f $SerialNumber, $host_name
} 
#____________________
function getProductVersion($exe_path){
    if ($exe_path | Test-Path) {
        $pv = (Get-ChildItem -Path $exe_path | Select-Object -ExpandProperty VersionInfo | Select-Object -ExpandProperty ProductVersion) -replace ",", "."
    } else {
        $pv = 'NF'
    }
    $pv
}

function getProductVersion_v2($exe_path, $key){
    if ($exe_path | Test-Path) {
        $pv = (Get-ItemProperty -Path $exe_path -Name $key).$key
    } else {
        $pv = 'NF'
    }
    $pv
} 

function getProductVersion_v3($name){
    try {
        $pv = (Get-Package -Name "$name" | Select-Object -ExpandProperty Version)
    } catch {
        $pv = 'NF'
    }
    $pv
} 

$raw_time
exit 0 