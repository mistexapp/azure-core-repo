<#
    Project Name: Geolocation
    Version: 3
#>

$project = "Geolocation"
$time = 12000
$ErrorActionPreference = "Continue"
function start_project {
    $version = 3

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

    function get_coordinates($prop){
        Add-Type -AssemblyName System.Device
        $GeoWatcher = New-Object System.Device.Location.GeoCoordinateWatcher
        $GeoWatcher.Start()
        while (($GeoWatcher.Status -ne 'Ready') -and ($GeoWatcher.Permission -ne 'Denied')) {
            Start-Sleep -Milliseconds 50
        }

        if (-not($GeoWatcher.Permission -eq 'Denied')){
            $v = ($GeoWatcher.Position.Location | Select-Object -ExpandProperty $prop) -replace ',', '.'
        } else { $v = "0" }
        $GeoWatcher.Stop()
        $v
    }

    $obj = [PSCustomObject]@{
        serialnumber = IsValNull $_check.serial_number
        user_latitude = IsValNull (get_coordinates 'Latitude' )
        user_longitude = IsValNull (get_coordinates 'Longitude' )
        map_url = IsValNull ("https://www.google.com/maps/search/?api=1&query={0},{1}" -f $user_latitude, $user_longitude)
        geo_version = IsValNull $version
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
        try{
            stop-transcript|out-null
        } catch [System.InvalidOperationException]{}
    }
    
} catch {
    Write-Host "Can't check script info"
    Write-Host $_
    try{
        stop-transcript|out-null
    } catch [System.InvalidOperationException]{}
} 