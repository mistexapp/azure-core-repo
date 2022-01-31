$source = 'https://box.admitad.com/index.php/s/jK4SwXW6TFKrRLA/download/windows64full_8_3_18_1741.zip'
$destination = 'C:\Users\Public\windows64full_8_3_18_1741.zip'
$completePath = 'C:\Users\Public\windows64full_8_3_18_1741'

$host_name = (Get-WmiObject Win32_OperatingSystem).CSName


function Unzip($zipfile, $outpath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

function getProduct($name){
    try {
        Get-Package -Name "$name" -ErrorAction Stop
        $installed = $true
    } catch {
        $installed = $false
    }
    
    return $installed
}


$pv_old = "*(8.3.18.1208)*"
$pv_new = "*(8.3.18.1741)*"
$check_old = getProduct $pv_old
$check_new = getProduct $pv_new

if ($check_old) {
    Write-Host "$pv_old is already installed." -ForegroundColor Green
    if ($check_new) {
        Write-Host "$pv_new is already installed." -ForegroundColor Green
        exit 9
    } else {
        Write-Host "[-] Products not found" -ForegroundColor Red
        Write-Host "[-][+] Installing $pv" -ForegroundColor Green
        if (-not (test-path $destination)) { 
            Invoke-WebRequest -Uri $source -OutFile $destination
        } else {
            Remove-Item -Path $destination -Recurse -Force -Confirm:$false | Out-Null
            if (test-path $completePath){
                Remove-Item -Path $completePath -Recurse -Force -Confirm:$false | Out-Null
            }
            Invoke-WebRequest -Uri $source -OutFile $destination
        }
        Unzip $destination 'C:\Users\Public\'
        & "$completePath\setup.exe" /S USEHWLICENSES=0 DESIGNERALLCLIENTS=0 THINCLIENT=1 THINCLIENTFILE=0 SERVER=0 WEBSERVEREXT=0 CONFREPOSSERVER=0 SERVERCLIENT=0 CONVERTER77=0
        
        sleep 240
        Remove-Item -Path $completePath -Recurse -Force -Confirm:$false | Out-Null
        Remove-Item -Path $destination -Recurse -Force -Confirm:$false | Out-Null
        exit 0
    }
}