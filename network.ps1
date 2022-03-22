<#
    Network

    ip, mac, speed, proxy and isp information
#>
#
$ErrorActionPreference = "Continue"
$project = "net"
$time = 14

. ".\_check.ps1"
try{
    $_check = _check $time $project 

    if (($_check.start) -and ($_check.start -eq 1)) {
        $logfile = "$_check.script_path\$project.log"
        Start-Transcript -path $logfile -Append:$false | Out-Null

        Write-Host $_check.raw_time -ForegroundColor DarkYellow
        start_project
        sleep(1)
        Stop-Transcript | Out-Null
        exit 0
        
    } else {
        Write-Host "Exit." -ForegroundColor Red
        Stop-Transcript | Out-Null
        exit 1
    }
    
} catch {
    Write-Host "Can't check script info"
    Stop-Transcript | Out-Null
    exit 1
}




function start_project {
    $version_network = 5
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


    #Proxy
    function get_proxy($property){
        $proxy_path = "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        if (test-path $proxy_path){
            try{
                [string] $value = Get-ItemProperty -Path $proxy_path | Select-Object -ExpandProperty $property
            }
            catch {
                [string] $value = 'Undefined'
            }
        }
        return $value
    }
    $proxy_enabled = get_proxy 'ProxyEnable'
    $proxy_server = get_proxy 'ProxyServer'


    $values = @($public_ip, $local_ip, $mac_addr, 
                $user_isp, $user_city, $user_country)
                #$download_speed, $upload_speed
                # $proxy_enabled, $proxy_server)

    foreach($v in $values){
        if ($v) {
            $v = $v -replace '[^\p{L}\p{Nd}]', '' #remove non utf-8 charters
            if (-not($v -cmatch '[^\x20-\x7F]')){ #if -ne non ansii 
                if( (-not ($v.GetType().Name -eq 'String')) -or ($v -eq 'System.Object[]')){
                    $v = 'Undefined'
                }
            } else {
                $v = 'Undefined'
            }
        }
    }

    if (Test-Path $download_path){
        Remove-Item $download_path
    } 

    #___________________________________________________________________________________________________________________________________________________________

    $values_array = @($SerialNumber,    #0
                    $download_speed,    #1
                    $upload_speed,      #2
                    $user_isp,          #3
                    $user_city,         #4
                    $user_country,      #5
                    $public_ip,         #6
                    $local_ip,          #7
                    $mac_addr,          #8
                    $proxy_enabled,     #9
                    $proxy_server,      #10
                    $version_network,   #11
                    $timestamp          #12
                    )


    $MessageBody = 'Network,host={0} download_speed="{1}",upload_speed="{2}",user_isp="{3}",user_city="{4}",user_country="{5}",public_ip="{6}",local_ip="{7}",mac="{8}",proxy_enabled="{9}",proxy_server="{10}",version_network="{11}" {12}' -f $values_array

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

    Sender $_check.token "$_check.url/api/v2/write?org=ITS&bucket=$_check.bucket&precision=s" $MessageBody
    Stop-Transcript | Out-Null
}