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


if (($host_name -eq "adm-test-0001") -or ($host_name -eq "adm-kyiv-0143") -or ($host_name -eq "ADM-MNS0233")) {
    $pv = "1C:Enterprise 8 (x86-64) (8.3.18.1741)"
    $check_installed = getProduct $pv

    if ($check_installed) {
        Write-Host "Product is already installed." -ForegroundColor Green
        exit 9
    } else {
        Write-Host "Products not found" -ForegroundColor Red
        Write-Host "Installing $pv" -ForegroundColor Green
        if (-not (test-path $destination)) { 
            Invoke-WebRequest -Uri $source -OutFile $destination
        } else {
            if (test-path $completePath){
                Remove-Item -Path $completePath -Recurse -Force -Confirm:$false | Out-Null
            }
        }
        Unzip $destination 'C:\Users\Public\'
        & "$completePath\setup.exe" /S USEHWLICENSES=0 DESIGNERALLCLIENTS=0 THINCLIENT=1 THINCLIENTFILE=0 SERVER=0 WEBSERVEREXT=0 CONFREPOSSERVER=0 SERVERCLIENT=0 CONVERTER77=0
        
        sleep 120
        Remove-Item -Path $completePath -Recurse -Force -Confirm:$false | Out-Null
        Remove-Item -Path $destination -Recurse -Force -Confirm:$false | Out-Null
        exit 0
    }
}