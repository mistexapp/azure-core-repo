 $ErrorActionPreference="SilentlyContinue"
Stop-Transcript | Out-Null
# Remove-Item -Path 'HKLM:\SOFTWARE\ITSupport\Software\Settings\'
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
$version_software = 4
$SerialNumber = (Get-WmiObject win32_bios | Select-Object -ExpandProperty serialnumber) -replace " "
$host_name = (Get-WmiObject Win32_OperatingSystem).CSName
if (($SerialNumber -like '*SystemSerialNumber*') -or ($SerialNumber -like '*Defaultstring*')) {
    $SerialNumber = "{0}-{1}" -f $SerialNumber, $host_name
} 
#____________________
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
##################################################

#policies
#$device_lock =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\DeviceLock' MaxInactivityTimeDeviceLock
#$bitlocker_required =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\BitLocker' RequireDeviceEncryption

#soft

$exceptions = @('Microsoft','Update','WindowsMaliciou','Realtek','Synaptics','NETFramework',
'king.com','Dolby','Goodix','KB','x64:','Fortemedia','SoundResearch','AdvancedMicroDevices','Click-to-Run',
'ELAN','Conexant','onedrive','DynamicApplication','OpenAL','Adapter','Camera','Skype','CCC','Java','SQL',
'Windows','Lenovo','Intel','HP','Hewlett','NVIDIA','Samsung','Logitech','ASUS','Surface','AMD',
'Qualcomm','Catalyst','Apple','Philips' )

#Исключения для Office и Visio phpstorm, Lenovo-System(может), amd64(попадает под AMD)
function val($s) {
    $null -ne ($exceptions | ? { $s -match $_ })
}

foreach ($program in Get-Package){
    $prog_name = ($program | Select-Object -ExpandProperty Name) -replace " " #-replace("1C", "C1")
    if (-not ($prog_name -cmatch '[^\x20-\x7F]')){
        if (-not(val $prog_name)){
            $prog_version = $program | Select-Object -ExpandProperty Version
            $to_send = 'Software,host={0} {1}="{2}" {3}' -f $SerialNumber, $prog_name, $prog_version, $timestamp
            #$to_send = $to_send -replace '[^\p{L}\p{Nd}]', ''  #remove non utf-8 charters
            Sender $token "$url/api/v2/write?org=ITS&bucket=$bucket&precision=s" $to_send
        }
    }
}

#Shadowsocks
$gui_conf = "C:\Users\Public\shadowsocks\gui-config.json"
if (Test-Path $gui_conf -PathType Leaf) {
    $js = ( Get-Content $gui_conf ) | ConvertFrom-Json
    $ss_ver = $js | Select-Object -ExpandProperty version
    $ss_ver_string = 'Software,host={0} shadowsocks="{1}" {2}' -f $SerialNumber, $ss_ver, $timestamp

    Sender $token "$url/api/v2/write?org=ITS&bucket=$bucket&precision=s" $ss_ver_string
}



$ver = 'Software,host={0} version_software="{1}" {2}' -f $SerialNumber, $version_software, $timestamp
Sender $token "$url/api/v2/write?org=ITS&bucket=$bucket&precision=s" $ver
#___________________________________________________________________________________________________________________________________________________________

#___________________________________________________________________________________________________________________________________________________________

$raw_time
exit 0  
