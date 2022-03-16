$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | Out-Null

$project = 'Network'
$start_time = 120 # 2h
$reg_path = "HKLM:\SOFTWARE\ITSupport\$project"
$script_path = "C:\Windows\System32\IntuneAdmins\$project"
$bucket = 'prod-db-sept'
$token = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "token").token
$url = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "url").url

if ($script_path | Test-Path){
    if (-ne ($project -eq 'Network')){
        Remove-Item -Path $script_path -Recurse -Force -Confirm:$false | Out-Null
    }
} else {
    New-Item -Path $script_path -Type Directory -force | Out-Null
}

$ErrorActionPreference = "Continue"
$logfile = "$script_path\$project.log"
Start-Transcript -path $logfile -Append:$false | Out-Null

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
#Network
$version_network = 3
$SerialNumber = (Get-WmiObject win32_bios | Select-Object -ExpandProperty serialnumber) -replace " "
$host_name = (Get-WmiObject Win32_OperatingSystem).CSName
if (($SerialNumber -like '*SystemSerialNumber*') -or ($SerialNumber -like '*Defaultstring*')) {
    $SerialNumber = "{0}-{1}" -f $SerialNumber, $host_name}
#_______________
$download_url = "https://install.speedtest.net/app/cli/ookla-speedtest-1.0.0-win64.zip"
$download_path = "C:\Windows\System32\IntuneAdmins\Network\SpeedTest.Zip"
$extract_to_path = "C:\Windows\System32\IntuneAdmins\Network\SpeedTest"
$speedtest_exe_path = "C:\Windows\System32\IntuneAdmins\Network\SpeedTest\speedtest.exe"
function RunTest(){
    $test = & $speedtest_exe_path --accept-license --format=json
    $test
}

function getSpeedtestDetails($param1, $param2){
    $exp = ($r | ConvertFrom-Json) | Select-Object -ExpandProperty $param1 | Select-Object -ExpandProperty $param2
    $exp
}

if (Test-Path $speedtest_exe_path -PathType leaf){
    Write-Host "SpeedTest EXE Exists, starting test" -ForegroundColor Green
    $r = RunTest 
}else{
    Write-Host "SpeedTest EXE Doesn't Exist, starting file download"
    wget $download_url -outfile $download_path
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    function Unzip{
        param([string]$zipfile, [string]$outpath)
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
    }
    Unzip $download_path $extract_to_path
    $r = RunTest
}

$user_isp = (($r | ConvertFrom-Json) | Select-Object -ExpandProperty isp)

if ( $r -ne $null -And $user_isp -ne ''){
    [string]$public_ip = getSpeedtestDetails interface externalIp
    [string]$local_ip = getSpeedtestDetails interface internalIp
    [string]$mac_addr = getSpeedtestDetails interface macAddr
    [string]$user_isp = ($r | ConvertFrom-Json) | Select-Object -ExpandProperty isp
    [string]$user_city = getSpeedtestDetails server location
    [string]$user_country = getSpeedtestDetails server country 
    [string]$download_speed = ((getSpeedtestDetails download bandwidth) / 125000) -replace ",", "."
    [string]$upload_speed = ((getSpeedtestDetails upload bandwidth) / 125000) -replace ",", "."
} else {
    [string]$public_ip = (Invoke-WebRequest -UseBasicParsing -uri "http://ifconfig.me/ip").Content
    $rr = Invoke-WebRequest -UseBasicParsing -uri ("https://ipinfo.io/{0}" -f $public_ip)
    $network_properties = (Get-WmiObject win32_networkadapterconfiguration | 
    Select-Object -Property @{
        Name = 'IPAddress'
        Expression = {($PSItem.IPAddress[0])}
    },MacAddress | Where IPAddress -NE $null)
    [string]$local_ip = $network_properties | Select-Object -ExpandProperty IPAddress
    [string]$mac_addr = $network_properties | Select-Object -ExpandProperty MacAddress
    [string]$user_isp = ($rr.Content | ConvertFrom-Json) | Select-Object -ExpandProperty org
    [string]$user_city = ($rr.Content | ConvertFrom-Json) | Select-Object -ExpandProperty city
    [string]$user_country = ($rr.Content | ConvertFrom-Json) | Select-Object -ExpandProperty country
    [string]$download_speed = 0
    [string]$upload_speed =  0
}


#if (-NOT ($mac_addr -is [String[]])) {
#    [string] $mac_addr =  'Undefined' #$mac_addr | Select-Object -first 1}
#if (-NOT ($local_ip -is [String[]])) {
#    [string] $local_ip = 'Undefined' #$local_ip | Select-Object -first 1}

#Unicode and non-Strings

$values = @($public_ip, $local_ip, $mac_addr, 
            $user_isp, $user_city, $user_country,
            $download_speed, $upload_speed)

foreach($v in $values){
    if (-not ($v.GetType().Name -eq 'String')){
        $v = 'Undefined'
    } else {
        if ($v -cmatch '[^\x20-\x7F]'){
            $v = 'Undefined'
        }
    }

    if ($v -eq 'System.Object[]'){
        $v = 'Undefined'
    }
}

if (Test-Path $download_path){
    Remove-Item $download_path
} 

#___________________________________________________________________________________________________________________________________________________________

$values_array = @($SerialNumber, #0
                $download_speed, #1
                $upload_speed, #2
                $user_isp, #3
                $user_city, #4
                $user_country, #5
                $public_ip, #6
                $local_ip, #7
                $mac_addr, #8
                $version_network, #9
                $timestamp #10
                )

$MessageBody = 'Network,host={0} download_speed="{1}",upload_speed="{2}",user_isp="{3}",user_city="{4}",user_country="{5}",public_ip="{6}",local_ip="{7}",mac="{8}",version_network="{9}" {10}' -f $values_array
$values_array | Format-List

Foreach ($x in ( Get-ScheduledTask | Select-Object TaskName)) {
    if ($x -like '*Network*'){
        $task_to_delete = $x | Select-Object -ExpandProperty TaskName
        Unregister-ScheduledTask -TaskName $task_to_delete -Confirm:$false
    }
}

#___________________________________________________________________________________________________________________________________________________________
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
Stop-Transcript | Out-Null
exit 0 
