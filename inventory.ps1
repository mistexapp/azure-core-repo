<#
    Project Name: Inventory
    Version: 4
#>

$project = "Inventory"
$time = 840
$ErrorActionPreference = "Continue"

function  start_project{
    $version = "4"

    $uptime_object = (get-date) - (gcim Win32_OperatingSystem).LastBootUpTime | Select-Object Days, Hours, Minutes, Seconds
    $win32_operatingsystem = Get-WmiObject -Class win32_operatingsystem
    $win32_physicalmemory = Get-CimInstance -Class Win32_PhysicalMemory
    $win32_processor = Get-WmiObject -Class Win32_Processor
    $win32_logicaldisk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
    $win32_computersystem = Get-WmiObject -Class Win32_ComputerSystem

    function IsValNull ($v) {
        if ($v -is [system.array]) {
            $v = $v[0]
        }
        if (-not ($v)) {
            $v = 'Undefined'
        }
        [string]$v
    }
    
    $obj = [pscustomobject]@{
        version = IsValNull $version
        request = IsValNull $_check.timestamp

        serialnumber = IsValNull $_check.serial_number
        hostname = IsValNull $win32_operatingsystem.CSName
        username = IsValNull (Get-Process -Name Explorer -IncludeUserName | Select-Object -ExpandProperty UserName)
        laptop =  IsValNull ("{0} {1}" -f  $win32_computersystem.Manufacturer, $win32_computersystem.Model) 
        
        os_name = "Windows"
        os_pn = IsValNull ($win32_operatingsystem.Caption -creplace "^.*?Windows ")
        os_build = IsValNull $win32_operatingsystem.BuildNumber
        os_uptime = IsValNull ("{0} days {1}:{2}" -f $uptime_object.Days, $uptime_object.Hours, $uptime_object.Minutes)
        os_language = IsValNull (GET-WinSystemLocale | Select-Object -ExpandProperty Name)
        os_installeddate = IsValNull (([WMI]'').ConvertToDateTime($win32_operatingsystem.InstallDate).ToString('dd.MM.yyyy'))

        ram_speed = IsValNull $win32_physicalmemory.Speed
        ram_usage = IsValNull ([math]::Round(((($win32_operatingsystem.TotalVisibleMemorySize - $win32_operatingsystem.FreePhysicalMemory)*100)/ $win32_operatingsystem.TotalVisibleMemorySize), 2) -replace ",", ".")
        ram_capacity = IsValNull ( ($win32_physicalmemory | Measure-Object -Property capacity -Sum).sum /1gb )
        ram_manufacturer = IsValNull $win32_physicalmemory.Manufacturer

        cpu_model = IsValNull (Get-WMIObject win32_Processor | Select-Object -ExpandProperty name)
        cpu_cores = IsValNull $win32_processor.NumberOfCores
        cpu_usage = IsValNull ($win32_processor.LoadPercentage -replace ",", ".")
        cpu_threads = IsValNull $win32_processor.NumberOfLogicalProcessors

        disk_size = IsValNull ([math]::Round($win32_logicaldisk.Size /1gb))
        disk_dirty =  IsValNull ([string]$win32_logicaldisk.VolumeDirty)
        disk_usage = IsValNull ([math]::Round((($win32_logicaldisk.Size - $win32_logicaldisk.FreeSpace) * 100) / $win32_logicaldisk.Size) )
    }

    $obj | Format-Table
    $m = "TestInv2,host={0} " -f $obj.serialnumber
    foreach ($x in ($obj | Get-Member -MemberType NoteProperty) | Select-Object -ExpandProperty Name) {
        $string1 = '{0}="{1}",' -f $x, $obj.$x
        $m += $string1
    }
    $m = $m.Substring(0,$m.Length-1)
    $m += " {0}" -f $_check.timestamp

    . "$PSScriptRoot\_send.ps1"
    _send $m
}

. "$PSScriptRoot\_check.ps1"
try{
    $_check = _check $time $project
    $script_path = $_check.script_path
    $logfile = "$script_path\$project.log"

    Start-Transcript -path $logfile -Append:$false | Out-Null

    if (($_check.start) -and ($_check.start -eq 1)) {
        if ( ((Get-WmiObject Win32_OperatingSystem).CSName) -like '*srv*') {
            Write-Host "Started: ", $_check.raw_time -ForegroundColor DarkGray
            start_project 
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
