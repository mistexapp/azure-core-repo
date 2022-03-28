<#
    Network
    ip, mac, speed, proxy and isp information
#>

$ErrorActionPreference = "Continue"
$project = "Network"
$time = 10


function start_project {
    $version_network = 6
    $SerialNumber = (Get-WmiObject win32_bios | Select-Object -ExpandProperty serialnumber) -replace " "
    $host_name = (Get-WmiObject Win32_OperatingSystem).CSName
    if (($SerialNumber -like '*SystemSerialNumber*') -or ($SerialNumber -like '*Defaultstring*')) {
        $SerialNumber = "{0}-{1}" -f $SerialNumber, $host_name}
    #_______________
    $download_url = "https://install.speedtest.net/app/cli/ookla-speedtest-1.0.0-win64.zip"
    $download_path = "C:\Windows\System32\IntuneAdmins\Network\SpeedTest.Zip"
    $extract_to_path = "C:\Windows\System32\IntuneAdmins\Network\SpeedTest"
    $speedtest_exe_path = "C:\Windows\System32\IntuneAdmins\Network\SpeedTest\speedtest.exe"

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
    function RunTest(){
        $test = & $speedtest_exe_path --accept-license --format=json
        $test
    }

    function getSpeedtestDetails($param1, $param2){
        $exp = ($r | ConvertFrom-Json) | Select-Object -ExpandProperty $param1 | Select-Object -ExpandProperty $param2
        $exp
    }

    if (Test-Path $speedtest_exe_path -PathType leaf){
        $r = RunTest 
    }else{
        #Write-Host "SpeedTest EXE Doesn't Exist, starting file download"
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
        $public_ip = getSpeedtestDetails interface externalIp
        $local_ip = getSpeedtestDetails interface internalIp
        $mac_address = getSpeedtestDetails interface macAddr
        $user_isp = ($r | ConvertFrom-Json) | Select-Object -ExpandProperty isp
        $user_city = getSpeedtestDetails server location
        $user_country = getSpeedtestDetails server country 
        $download_speed = ((getSpeedtestDetails download bandwidth) / 125000) -replace ",", "."
        $upload_speed = ((getSpeedtestDetails upload bandwidth) / 125000) -replace ",", "."
    } else {
        $public_ip = (Invoke-WebRequest -UseBasicParsing -uri "http://ifconfig.me/ip").Content
        $rr = Invoke-WebRequest -UseBasicParsing -uri ("https://ipinfo.io/{0}" -f $public_ip)
        $network_properties = (Get-WmiObject win32_networkadapterconfiguration | 
        Select-Object -Property @{
            Name = 'IPAddress'
            Expression = {($PSItem.IPAddress[0])}
        },MacAddress | Where IPAddress -NE $null)
        $local_ip = $network_properties | Select-Object -ExpandProperty IPAddress
        $mac_address = $network_properties | Select-Object -ExpandProperty MacAddress
        $user_isp = ($rr.Content | ConvertFrom-Json) | Select-Object -ExpandProperty org
        $user_city = ($rr.Content | ConvertFrom-Json) | Select-Object -ExpandProperty city
        $user_country = ($rr.Content | ConvertFrom-Json) | Select-Object -ExpandProperty country
        $download_speed = 0
        $upload_speed =  0
    }


    #Proxy
    function get_proxy($property){
        $proxy_path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        if (test-path $proxy_path){
            try{
                $value = Get-ItemProperty -Path $proxy_path | Select-Object -ExpandProperty $property }
            catch [System.InvalidOperationException]{}
            [string]$value
        }
    }

    if (Test-Path $download_path){
        Remove-Item $download_path
    } 

    #___________________________________________________________________________________________________________________________________________________________
    $obj = [PSCustomObject]@{
        serialnumber    = IsValNull $_check.serial_number
        download_speed  = IsValNull $download_speed
        upload_speed    = IsValNull $upload_speed
        user_isp        = IsValNull $user_isp
        user_city       = IsValNull $user_city
        user_country    = IsValNull $user_country
        public_ip       = IsValNull $public_ip
        local_ip        = IsValNull $local_ip
        mac_address     = IsValNull $mac_address
        proxy_enabled   = IsValNull (get_proxy 'ProxyEnable')
        proxy_server    = IsValNull (get_proxy 'ProxyServer')
        version_network = IsValNull $version_network
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
        try { stop-transcript|out-null }
        catch [System.InvalidOperationException]{}
    }
    
} catch {
    Write-Host "Can't check script info"
    Write-Host $_
    try{
        stop-transcript|out-null
    } catch [System.InvalidOperationException]{}
}
