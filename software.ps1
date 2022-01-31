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

#policies
$device_lock =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\DeviceLock' MaxInactivityTimeDeviceLock
$bitlocker_required =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\BitLocker' RequireDeviceEncryption
#soft
$pritunl_v = getProductVersion 'C:\Program Files (x86)\Pritunl\pritunl.exe'
$sharex_v = getProductVersion 'C:\Program Files\ShareX\ShareX.exe'
$vlc_v = getProductVersion 'C:\Program Files\VideoLAN\VLC\vlc.exe'
$teamviewer_v = getProductVersion 'C:\Program Files (x86)\TeamViewer\TeamViewer.exe'
$slack_machine_wide =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Inventories\0C89B80D-B880-4A71-A28E-6FDFEEF789C8' Version
$slack_dep_tool =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Inventories\F2DE7595-77A0-4DA6-924B-C0A70FFB245C' Version
$zip_v =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Inventories\23170F69-40C1-2702-1900-000001000000' Version
$python =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Inventories\3B53E5B7-CFC4-401C-80E9-FF7591C58741' Version
$wazuh_v =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Inventories\5FCB6691-88DF-4F3E-8C42-79DECB4E85CE' Version
$esetma_v =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Inventories\803B32D1-B688-4CF5-AE19-4559D120C299' Version
$office_v =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Inventories\90160000-0011-0000-1000-0000000FF1CE' Version
$eseteantivirus_v =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Inventories\CAC9C8AF-7485-48E0-AF87-FDC929B57E76' Version
$acrobat =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Inventories\AC76BA86-7AD7-1049-7B44-AC0F074E4100' Version
$chrome_v =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Inventories\FBA1CA29-5F56-32B9-BCAF-5C023F658346' Version
$c1 =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Inventories\EC8EF2A8-4B63-4CBD-90E5-34AB21A99179' Version

$intune_me =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Inventories\B5E9F333-9FC6-4F5C-999C-C3CDDF669A30' Version
#trash
$xerox =  getProductVersion_v2 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Inventories\A8646D99-7B07-216B-3C1D-8D2F6B8E2141' Version 
$avast = getProductVersion_v3 "*Avast*"
$с1_1741 = getProductVersion_v3 "1C:Enterprise 8 (x86-64) (8.3.18.1741)"
$с1_1208 = getProductVersion_v3 "1C:Enterprise 8 (x86-64) (8.3.18.1208)"
$driverbooster = getProductVersion_v3 "*Booster*"
$libre = getProductVersion_v3 "*Libre*"
$webadvisor = getProductVersion_v3 "*WebAdvisor*"

#___________________________________________________________________________________________________________________________________________________________
$values_array = @($SerialNumber, #0
                $pritunl_v, #1
                $zip_v, #2
                $sharex_v, #3
                $vlc_v, #4
                $teamviewer_v, #5
                $chrome_v, #6
                $eseteantivirus_v, #7
                $esetma_v, #8
                $slack_machine_wide, #9
                $slack_dev_tool, #10
                $office_v, #11
                $wazuh_v, #12
                $python, #13
                $acrobat, #14
                $c1, #15
                $intune_me, #16
                $device_lock, #17
                $bitlocker_required, #18
                $xerox, #19
                $timestamp, #20
                $version_software, #21
                $avast, #22
                $driverbooster, #23
                $libre, #24
                $webadvisor, #25
                $с1_1741, #26
                $с1_1208 #27
                )

$soft = 'Software,host={0} pritunl="{1}",zip="{2}",sharex="{3}",vlc="{4}",teamviewer="{5}",chrome="{6}",eseteantivirus="{7}",esetma="{8}",slack_mw="{9}",slack_dt="{10}",office="{11}",wazuh="{12}",python="{13}",acrobat="{14}",c1="{15}",intune_me="{16}",version_software="{21}",c1_1208="{27}",c1_1741="{26}" ' -f $values_array
$policies = 'Policies,host={0} device_lock="{17}",bitlocker_required="{18}"' -f $values_array
$trash = 'Trash,host={0} xerox="{19}",avast="{22}",driverbooster="{23}",libre="{24}",webadvisor="{25}" {20}' -f $values_array
$MessageBody = "$soft`n`n$policies`n`n$trash"
$values_array | Format-List
#___________________________________________________________________________________________________________________________________________________________
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
echo "hhhhh"
$raw_time
exit 0 