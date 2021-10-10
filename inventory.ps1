$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | Out-Null

$project = 'Inventory'
$start_time = 90
$reg_path = "HKLM:\SOFTWARE\ITSupport\$project"
$script_path = "C:\Windows\System32\IntuneAdmins\$project"
$bucket = 'prod-db-sept'
$token = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "token").token
$url = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "url").url

if ($script_path | Test-Path){
    Remove-Item -Path $script_path -Force -Confirm:$false
} else {
    New-Item -Path $script_path -force | Out-Null
}

$ErrorActionPreference = "Continue"
$logfile = "$script_path\$project.log"
Start-Transcript -path $logfile -Append:$false | Out-Null
#___________________________________________________________________________________________________________________________________________________________
$raw_time = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now,"Russian Standard Time")
$timestamp = ([DateTimeOffset]$raw_time).ToUnixTimeSeconds()

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
#General
$Version = 27
$SerialNumber = (Get-WmiObject win32_bios | Select-Object -ExpandProperty serialnumber) -replace " "
$host_name = (Get-WmiObject Win32_OperatingSystem).CSName
if (($SerialNumber -like '*SystemSerialNumber*') -or ($SerialNumber -like '*Defaultstring*')) {
    $SerialNumber = "{0}-{1}" -f $SerialNumber, $host_name}
$uname = (Get-Process -Name Explorer -IncludeUserName | Select-Object -ExpandProperty UserName) 
if (-NOT ($uname -like '*AzureAD*')){ $uname = ("{0}[local]" -f $uname).Split('\')[-1] } else { $uname = $uname.Split('\')[-1] }
$department = (Get-WmiObject -Class Win32_OperatingSystem |Select-Object -ExpandProperty Description)
if((Get-Bitlockervolume).ProtectionStatus -eq 'On' -and (Get-Bitlockervolume).EncryptionPercentage -eq '100'){
    $os_encryption = 1
} else {
    $os_encryption = 0
}

#___________________________________________________________________________________________________________________________________________________________
#OS details
$OS_Name = "Windows"
$OS_ProductName = (Get-WmiObject Win32_OperatingSystem).Caption -creplace "^.*?Windows"
$OS_Build = ([System.Environment]::OSVersion.Version | Select-Object -ExpandProperty Build)
$uptime_object = (get-date) - (gcim Win32_OperatingSystem).LastBootUpTime | Select-Object Days, Hours, Minutes, Seconds
$OS_Uptime = "{0} days {1}:{2}" -f $uptime_object.Days, $uptime_object.Hours, $uptime_object.Minutes
$OS_Language = GET-WinSystemLocale | Select-Object -ExpandProperty Name
$OS_InstalledDate = (([WMI]'').ConvertToDateTime((Get-WmiObject Win32_OperatingSystem).InstallDate).ToString('dd.MM.yyyy'))
$userslist = New-Object Collections.Generic.List[String]

#___________________________________________________________________________________________________________________________________________________________

#Hardware
Function Detect-Laptop{
    Param( [string]$computer = “localhost” )
    $isLaptop = $false
    if(Get-WmiObject -Class win32_systemenclosure -ComputerName $computer | Where-Object { $_.chassistypes -eq 9 -or $_.chassistypes -eq 10 -or $_.chassistypes -eq 14})
    {
        $isLaptop = $true
    }
    $isLaptop
} 
#Hardware.Monitors
function Decode {
    If ($args[0] -is [System.Array]) {
        [System.Text.Encoding]::ASCII.GetString($args[0])
    }
    Else {
        "-"
    }
}

$monitors_obj = Get-WmiObject WmiMonitorID -Namespace root\wmi

$monitor_name0 = Decode $monitors_obj[0].UserFriendlyName -notmatch 0
$monitor_serial0 = Decode $monitors_obj[0].SerialNumberID -notmatch 0
$monitor_name1 = Decode $monitors_obj[1].UserFriendlyName -notmatch 0
$monitor_serial1 = Decode $monitors_obj[1].SerialNumberID -notmatch 0
$monitor_name2 = Decode $monitors_obj[2].UserFriendlyName -notmatch 0
$monitor_serial2 = Decode $monitors_obj[2].SerialNumberID -notmatch 0 

#Hardware.RAM
$RAM_Capacity = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum /1gb
$RAM_Manufacturer = (Get-CimInstance Win32_PhysicalMemory | Select-Object -ExpandProperty Manufacturer)
if (-NOT ($RAM_Manufacturer -is [String])) {
    $RAM_Manufacturer=$RAM_Manufacturer[0]}
$RAM_Speed = (Get-CimInstance Win32_PhysicalMemory | Select-Object -ExpandProperty Speed)
if (-NOT ($RAM_Speed -is [String])) {
    $RAM_Speed=$RAM_Speed[0]}

$ComputerMemory = Get-WmiObject -Class win32_operatingsystem
$RAM_Usage = [math]::Round(((($ComputerMemory.TotalVisibleMemorySize - $ComputerMemory.FreePhysicalMemory)*100)/ $ComputerMemory.TotalVisibleMemorySize), 2) -replace ",", "."

#Hardware.CPU

$CPU_Model = (Get-WMIObject win32_Processor | Select-Object -ExpandProperty name) 
if ($CPU_Model -like '*Intel(R) Xeon(R) CPU*'){ 
    $CPU_Model = $CPU_Model -replace ([regex]::Escape('Intel(R) Xeon(R) CPU ')), "Xeon "
} elseif ($CPU_Model -like '*Eight-Core Processor*'){ 
    $CPU_Model = $CPU_Model -replace ([regex]::Escape('Eight-Core Processor')), ""
} elseif ($CPU_Model -like '*Intel(R) Core(TM)*'){ 
    $CPU_Model = $CPU_Model -replace ([regex]::Escape('Intel(R) Core(TM) ')), "Core "
} elseif ($CPU_Model -like '*Microsoft Corporation*'){ 
    $CPU_Model = $CPU_Model -replace ([regex]::Escape('Microsoft Corporation ')), ""
} elseif ($CPU_Model -like '*ASUSTeK COMPUTER INC.*'){ 
    $CPU_Model = $CPU_Model -replace ([regex]::Escape('ASUSTeK COMPUTER INC. ')), "Asus "
} elseif ($CPU_Model -like '*11th Gen Core*'){ 
    $CPU_Model = $CPU_Model -replace ([regex]::Escape('11th Gen Core ')), "Core  "
}

$CPU_Cores = Get-WmiObject -Class Win32_Processor | Select-Object -ExpandProperty NumberOfCores
$CPU_Threads = Get-WmiObject -Class Win32_Processor | Select-Object -ExpandProperty NumberOfLogicalProcessors
$CPU_Usage = (Get-WmiObject Win32_Processor | Select -ExpandProperty LoadPercentage) -replace ",", "."
if (-NOT ($CPU_Usage -is [String])) {
    $CPU_Usage="0"}

#Hardware.Disk-C
foreach ($disk in (Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object Size,FreeSpace )){
    $Disk_Size = [math]::Round($disk.Size /1gb)
    $Disk_Usage = [math]::Round((($disk.Size - $disk.FreeSpace) * 100) / $disk.Size)
}

#Hardware.LaptopModel
$l_model = (Get-WmiObject Win32_ComputerSystem).model
$l_manufacturer = (Get-WmiObject Win32_ComputerSystem).manufacturer
$laptop = "{0} {1}" -f $l_manufacturer, $l_model

if ($laptop -like '*Gigabyte Technology Co., Ltd.*'){ 
    $laptop = $laptop -replace "Gigabyte Technology Co., Ltd. ", "Gigabyte "
} elseif ($laptop -like '*HP HP*'){ 
    $laptop = $laptop -replace"HP HP ", "HP "
} elseif ($laptop -like '*Dell Inc.*'){ 
    $laptop = $laptop -replace"Dell Inc. ", "Dell "
} 

#Hardrare.Battery
If(Detect-Laptop) {
    $BattAssembly = [Windows.Devices.Power.Battery,Windows.Devices.Power.Battery,ContentType=WindowsRuntime]
    Try {
        $Report = [Windows.Devices.Power.Battery]::AggregateBattery.GetReport()
        If ($Report.Status -ne "NotPresent"){
            $pbmax = [convert]::ToDouble($Report.FullChargeCapacityInMilliwattHours)
            $pbvalue = [convert]::ToDouble($Report.RemainingCapacityInMilliwattHours)
            $battery_capacity = [int][math]::Round( (($pbvalue / $pbmax) *100))
            $battery_charging = ($Report.Status  | Out-String).Trim()
            if ($battery_charging -eq 'Idle') { $battery_charging = 'Discharging' }
        } Else {
            $battery_charging = '----'
            $battery_capacity = 0.0001
        }
    } Catch {
        $battery_charging = '----'
        $battery_capacity = 0.0001
    }
} Else {
    $battery_charging = 'No batteries'
    $battery_capacity=100
}
#___________________________________________________________________________________________________________________________________________________________
$values_array = @($SerialNumber, #0
                $host_name, #1
                $uname, #2
                $SerialNumber, #3
                $Version, #4
                $laptop, #5
                $timestamp, #6
                $CPU_Model, #7
                $CPU_Usage, #8
                $CPU_Cores, #9
                $CPU_Threads, #10
                $RAM_Capacity, #11
                $RAM_Manufacturer, #12
                $RAM_Usage, #13
                $RAM_Speed, #14
                $battery_charging, #15
                $battery_capacity, #16
                $Disk_Size, #17
                $OS_Name, #18
                $OS_Build, #19
                $OS_ProductName, #20
                $OS_Uptime, #21
                $OS_Language, #22
                $OS_InstalledDate, #23
                $os_encryption, #24
                $monitor_name0, #25
                $monitor_serial0, #26
                $monitor_name1, #27
                $monitor_serial1, #28
                $monitor_name2, #29
                $monitor_serial2 #30
                )

$general_line = 'General,host={0} hostname="{1}",username="{2}",serialnumber="{3}",version="{4}",laptop="{5}",encryption="{24}",request="{6}" ' -f $values_array
$cpu_line = 'CPU,host={0} cpu_model="{7}",cpu_usage="{8}",cpu_cores="{9}",cpu_threads=" {10}"' -f $values_array
$memory_line = 'Memory,host={0} mem_capacity="{11}",mem_manufacturer="{12}",mem_usage="{13}",mem_speed="{14}"' -f $values_array
$battery_line = 'Battery,host={0} batt_charging="{15}",batt_capacity="{16}"' -f $values_array
$disk_line = 'Disk,host={0} disks="{17}"' -f $values_array
$operationsystem_line = 'OperationSystem,host={0} os_name="{18}",os_build="{19}",os_product_name="{20}",os_uptime="{21}",os_language="{22}",os_installed_date="{23}"' -f $values_array
$monitors_line = 'Monitors,host={0} monitor1="{25}",monitor1_sn="{26}",monitor2="{27}",monitor2_sn="{28}",monitor3="{29}",monitor3_sn="{30}" {6}' -f $values_array

$MessageBody = "$general_line`n`n$cpu_line`n`n$memory_line`n`n$battery_line`n`n$disk_line`n`n$operationsystem_line`n`n$monitors_line"
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
exit 0 
