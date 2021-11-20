$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | Out-Null

$project = 'Cleaner'
$start_time = 900 #2592000 # 30d
$reg_path = "HKLM:\SOFTWARE\ITSupport\$project"
$script_path = "C:\Windows\System32\IntuneAdmins\$project"
$bucket = 'prod-db-sept'
$token = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "token").token
$url = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "url").url
$csv_file = "$script_path\response.csv"

if ($script_path | Test-Path){
    Remove-Item -Path $script_path -Recurse -Force -Confirm:$false | Out-Null
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
#Cleaner 
$version_cleaner = 4
$SerialNumber = (Get-WmiObject win32_bios | Select-Object -ExpandProperty serialnumber) -replace " "
$host_name = (Get-WmiObject Win32_OperatingSystem).CSName
if (($SerialNumber -like '*SystemSerialNumber*') -or ($SerialNumber -like '*Defaultstring*')) {
    $SerialNumber = "{0}-{1}" -f $SerialNumber, $host_name
}


# Driver Booster
$prog = "DriverBooster"
$booster_folder = "C:\Program Files (x86)\IObit\Driver Booster"
if ($booster_folder | Test-Path) {
    cd "$booster_folder\6.0.2\"
    try {
        .\unins000.exe /VERYSILENT /NORESTART
        $driverbooster = " :: Uninstalled. Deleting folder"
    } catch {
        $driverbooster = " :: Found folder only. Deleting..."
    }
    cd c:\
    sleep 20
    Remove-Item $booster_folder -Force -Recurse -Confirm:$false
} else {
    $driverbooster = " :: Not Found"
}

#McAfee WebAdvisor
$prog = "webadvisor"
$webadvisor_folder = "C:\Program Files\McAfee\WebAdvisor\"
if ($webadvisor_folder | Test-Path) {
    cd $webadvisor_folder
    try {
        .\uninstaller.exe /s
        $webadvisor = " :: Uninstalled."
    } catch {
        $webadvisor = " :: Found folder only. Deleting..."
    }
    cd c:\
    sleep 20
    Remove-Item "C:\Program Files\McAfee\"  -Recurse -Force -Confirm:$false
} else {
    $webadvisor = " :: Not Found"
}
#___________________________________________________________________________________________________________________________________________________________

Function GetInfluxValues($token=$token){

    $db = "$url/api/v2/query?org=ITS"
    $body = 'from(bucket:"constants")
        |> range(start: -12d)
        |> filter(fn: (r) => r["_measurement"] == "telegram")
        |> filter(fn: (r) => r["_field"] == "chat" or r["_field"] == "bot")
        |> drop(columns: ["_time", "_start", "_stop", "_result", "_measurement"])'

    $eval = Invoke-RestMethod -Headers @{
        "Authorization" = "Token $token"
        "Content-Type" = "application/vnd.flux"
        "Accept" = "application/csv"
        } `
                -Method POST `
                -Uri $db `
                -Body $body `
                > $csv_file
}

Function Telegram($BotToken, $ChatID, $Message){
    $payload = @{
        "chat_id"                   = $ChatID
        "text"                      = $Message
        "parse_mode"                = 'Markdown'
        "disable_web_page_preview"  = $true
        "disable_notification"      = $true
    }

    try {
        $eval = Invoke-RestMethod `
            -Uri ("https://api.telegram.org/bot{0}/sendMessage" -f $BotToken) `
            -Method Post `
            -ContentType "application/json" `
            -Body (ConvertTo-Json -Compress -InputObject $payload) `
            -ErrorAction Stop
        if (!($eval.ok -eq "True")) {
            $results = $false
        } else {
            $results = $true
            }
    } catch {
        $results = $false
    }
}

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


#___________________________________________________________________________________________________________________________________________________________
$values_array = @($SerialNumber, #0
                $version_cleaner, #1
                $timestamp #2
                )

$MessageBody = 'Cleaner,host={0} version_cleaner="{1}" {2}' -f $values_array

$text = "
Time: $raw_time
*Project*: $project
*Version*: $version_cleaner
*Host*: $host_name
*SeralNumber*: $SerialNumber
-----------
driverbooster $driverbooster
webadvisor $webadvisor
"

GetInfluxValues
Import-Csv -Path $csv_file -delimiter "," |`
        ForEach-Object {
            if ($_._field -eq 'bot'){
                $bot = $_._value       
                }
            if ($_._field -eq 'chat'){
                $chat_id = $_._value    
                }
        }
#___________________________________________________________________________________________________________________________________________________________



Sender $token "$url/api/v2/write?org=ITS&bucket=$bucket&precision=s" $MessageBody
Telegram $bot $chat_id $text
Remove-Item -Path $csv_file -Force
Stop-Transcript | Out-Null
exit 0  
 
