$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | Out-Null

$project = 'GeoSender'
$start_time = 7080 # 118 min
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

#Delete old GeoSender tasks
#_________________________________
Foreach ($x in ( Get-ScheduledTask | Select-Object TaskName)) {
    if ($x -like '*GeoSender*'){
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

#____________________________________________________________________________________________________________________________________________________
# Getting a location
$version = 2

$SerialNumber = (Get-WmiObject win32_bios | Select-Object -ExpandProperty serialnumber) -replace " "
$host_name = (Get-WmiObject Win32_OperatingSystem).CSName
if (($SerialNumber -like '*SystemSerialNumber*') -or ($SerialNumber -like '*Defaultstring*')) {
    $SerialNumber = "{0}-{1}" -f $SerialNumber, $host_name
} 
#__________________________________
Add-Type -AssemblyName System.Device
$GeoWatcher = New-Object System.Device.Location.GeoCoordinateWatcher
$GeoWatcher.Start()

while (($GeoWatcher.Status -ne 'Ready') -and ($GeoWatcher.Permission -ne 'Denied')) {
    Start-Sleep -Milliseconds 5000
}  

if ($GeoWatcher.Permission -eq 'Denied'){
    Write-Error = 'Access Denied for Location Information'
    $user_latitude = "0" 
    $user_longitude = "0"
} else {
    $user_latitude = ($GeoWatcher.Position.Location | Select-Object -ExpandProperty Latitude) -replace ',', '.'
    $user_longitude = ($GeoWatcher.Position.Location | Select-Object -ExpandProperty Longitude) -replace ',', '.'
}
#____________________________________________________________________________________________________________________________________________________
#Reques_time
$raw_time = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now,"Russian Standard Time")
$timestamp = ([DateTimeOffset]$raw_time).ToUnixTimeSeconds()
#$f_timestamp =  Get-Date -Format "dd-MM-yyyy_HH:mm"

$map_url = "https://www.google.com/maps/search/?api=1&query={0},{1}" -f $user_latitude, $user_longitude

#____________________________________________________________________________________________________________________________________________________
# Creating the location proporties_object


$values_array = @($SerialNumber, #0
                $user_latitude, #1
                $user_longitude, #2
                $map_url, #3
                $version, #4
                $timestamp #5
                )

$MessageBody = 'Geolocation,host={0} latitude="{1}",longitude="{2}",map_url="{3}",geo_version="{4}" {5}' -f $values_array
$values_array | Format-List

#____________________________________________________________________________________________________________________________________________________
Stop-Transcript | Out-Null

Function Sender($t, $u, $m){
Invoke-RestMethod -Headers @{
    "Authorization" = "Token $t"
    "Content-Type" = "text/plain; charset=utf-8"
    "Accept" = "application/json"
    } `
                -Method POST `
                -Uri  $u `
                -Body $m
}

Sender $token "$url/api/v2/write?org=ITS&bucket=$bucket&precision=s" $MessageBody
exit 0 