 $source = 'https://box.admitad.com/index.php/s/jK4SwXW6TFKrRLA/download/windows64full_8_3_18_1741.zip'
 $destination = 'C:\Users\Public\windows64full_8_3_18_1741.zip'
$completePath = 'C:\Users\Public\windows64full_8_3_18_1741'

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

function install($destination, $source, $completePath) {
    if (-not (test-path $destination)) { 
        Invoke-WebRequest -Uri $source -OutFile $destination
    } else {
        Remove-Item -Path $destination -Recurse -Force -Confirm:$false | Out-Null
        sleep 2
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
    
}




$pv_old = "*(8.3.18.1208))*"
$pv_new = "*(8.3.18.1741)*"
$check_old = getProduct $pv_old
$check_new = getProduct $pv_new

if ($check_old) {
    Write-Host "$pv_old is already installed." -ForegroundColor Green
    if ($check_new) {
        Write-Host "$pv_new is already installed." -ForegroundColor Green
        exit 9
    } else {
        Write-Host "[-] $pv_new - not found" -ForegroundColor Red
        Write-Host "[-][+] Installing $pv_new" -ForegroundColor Green
        install $destination $source $completePath
        exit 0
    }
} else {
    if (Test-Path 'C:\Program Files\1cv8\8.3.18.1208'){
        Write-Host "$pv_old is already installed (by Folder)." -ForegroundColor Green
        if (Test-Path 'C:\Program Files\1cv8\8.3.18.1741'){
            Write-Host "$pv_new is already installed (by Folder)." -ForegroundColor Green
            exit 9
        } else {
            Write-Host "[-] Products not found (by Folder)" -ForegroundColor Red
            Write-Host "[-][+] Installing $pv_new" -ForegroundColor Green
            install $destination $source $completePath
            exit 0
        }
    } 
    
} 
