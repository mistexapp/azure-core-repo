  <#
    _check

    to check availability of resources and runtime.
#>

function _check {
    param (
    [Parameter(Mandatory=$true)]
    [int]$start_time,
    [string]$project = 'test'
    )
    
    $reg_path = "HKLM:\SOFTWARE\ITSupport\$project"
    $script_path = "C:\Windows\System32\IntuneAdmins\$project"
    $token = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "token").token
    $url = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "url").url
    $bucket = 'prod-db-sept'

    
    if ($script_path | Test-Path){
        if (-not ($project -eq 'Network')){
            Remove-Item -Path $script_path -Recurse -Force -Confirm:$false | Out-Null
        }
    } else {
        New-Item -Path $script_path -Type Directory -force | Out-Null
    }

    #___________________________________________________________________________________________________________________________________________________________
    $raw_time = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now,"Russian Standard Time")
    $timestamp = ([DateTimeOffset]$raw_time).ToUnixTimeSeconds()

    function RegistryValue($Path, $VarName, $VarValue) {
        if ($Path | Test-Path){
            try {
                Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $VarName -ErrorAction Stop | Out-Null
                if ($VarName -eq 'time'){
                    try{
                        $presented_value = (Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $VarName) }
                    catch {
                        $presented_value = 0
                    }
                    if (!($presented_value -eq  $VarValue)){
                        New-ItemProperty -Path $Path -Name $VarName -Value $VarValue -Force | Out-Null
                        #Write-Host "New time is: [$VarValue]" -ForegroundColor Yellow
                    } else {
                        #Write-Host "Time is the same [$VarValue]" -ForegroundColor Green
                    }
                }
                if ($VarName -eq 'lastRequest'){
                    $presented_value = (Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $VarName)
                    $time = Get-ItemProperty -Path $Path | Select-Object -ExpandProperty time
                    $delta = $VarValue - $presented_value
                    if ($delta -ge  $time){
                        $start_script = 1
                        #Write-Host "OK! DeltaTime is [$delta]. Starting..." -ForegroundColor Green
                        New-ItemProperty -Path $Path -Name $VarName -Value $VarValue -Force | Out-Null
                    } else {
                        Write-Host "Passing. deltatime is [$delta] sec, but ExecuteTimeRange is [$time] sec." -ForegroundColor Red
                        $start_script = 0
                    }
                }
            }
            catch {
                Write-Host "[Path exist] -but- [$VarName[$VarValue]] was created." -ForegroundColor Magenta
                New-ItemProperty -Path $Path -Name $VarName -Value $VarValue -Force | Out-Null
                $start_script = 1
            }
        } else {
            #Write-Host "[$Path] -and- [$VarName[$VarValue]] were created." -ForegroundColor Magenta
            New-Item -Path $Path -force | Out-Null
            New-ItemProperty -Path $Path -Name $VarName -Value $VarValue -Force | Out-Null
            $start_script = 1
        }

        $obj = [pscustomobject]@{
            start = $start_script
            timestamp = $timestamp
            raw_time = $raw_time
            script_path = $script_path
            token = $token
            url = $url
            bucket = $bucket
        }

        if ($VarName -eq 'lastRequest') {
            $obj
        }
    }

    RegistryValue "$reg_path\Settings" time $start_time
    RegistryValue "$reg_path\Settings" lastRequest $timestamp

    
    
    $obj
} 
 
