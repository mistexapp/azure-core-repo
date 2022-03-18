 $7ZipPath = '"C:\Program Files\7-Zip\7z.exe"'
$zipFile = "C:\Users\Public\shadowsocks.zip"
$token = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "token").token
$url = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "url").url
$csv_file = "C:\users\public\response.csv"

function create_link($path) {
    New-Item -ItemType SymbolicLink -Path "C:\Users\Public\Desktop" -Name "Shadowsocks" -Value $path
}

function link(){
    create_link "C:\Users\Public\shadowsocks\Shadowsocks.exe" -Recurse -Force -Confirm:$false | Out-Null
}

function unzip($zipFile, $passwd) {
    if (Test-Path "C:\Program Files\7-Zip\7z.exe" -PathType Leaf ) {
        $command = "& $7ZipPath e -oC:\Users\Public\shadowsocks -y -tzip -p$passwd $zipFile"
        Invoke-Expression $command | Out-Null
        sleep(4)
        link
        Remove-Item $zipFile -Force -Confirm:$false | Out-Null
    }
}

Function get_details($token=$token){
    $db = "$url/api/v2/query?org=ITS"
    $body = 'from(bucket:"constants")
        |> range(start: -365d)
        |> filter(fn: (r) => r["_measurement"] == "ss")
        |> drop(columns: ["_time", "_start", "_stop", "_result", "_measurement"])'

    Invoke-RestMethod -Headers @{
        "Authorization" = "Token $token"
        "Content-Type" = "application/vnd.flux"
        "Accept" = "application/csv"
        } `
                -Method POST `
                -Uri $db `
                -Body $body `
                > $csv_file
}

function insert_v ($srv_name, $srv_port, $srv_pwd) {

    (Get-Content 'C:\Users\Public\shadowsocks\gui-config.json') `
    -replace 'port_example', $srv_port `
    -replace 'srv_example', $srv_name `
    -replace 'pwd_example', $srv_pwd |
    Out-File 'C:\Users\Public\shadowsocks\gui-config.json'
}

function go($passwd, $file_url){
    if (-not (Test-Path "C:\Users\Public\shadowsocks\Shadowsocks.exe" -PathType Leaf )) {
        if (Test-Path "C:\Users\Public\shadowsocks") {
            Remove-Item "C:\Users\Public\shadowsocks" -Recurse -Force -Confirm:$false | Out-Null
        }
        $link = "C:\Users\Public\Desktop\Shadowsocks"
        if (test-path $link) { 
            Remove-Item $link -Force
        }
        if (Test-Path $zipFile -PathType Leaf ) {
            unzip $zipFile $passwd 
        } else {
            Write-Host "shadowsocks.zip doesn't Exist." -ForegroundColor Yellow
            wget $file_url -outfile $zipFile
            sleep(2)
            unzip $zipFile $passwd
        }
    } else {
        Write-Host "shadowsocks already exists" -ForegroundColor Green
    }
}

$host_name = (Get-WmiObject Win32_OperatingSystem).CSName
if (-not($host_name -like '*srv*')) {
    get_details
    Import-Csv -Path $csv_file -delimiter "," |`
            ForEach-Object {
                if ($_._field -eq 'pwd_zip'){
                    $pwd_zip = $_._value  -replace " " 
                    }
                if ($_._field -eq 'file_id'){
                    $file_id = $_._value  -replace " "
                    }
                if ($_._field -eq 'srv_name'){
                    $srv_name = $_._value  -replace " "
                    }
                if ($_._field -eq 'srv_port'){
                    $srv_port = $_._value  -replace " "
                    }
                if ($_._field -eq 'srv_pwd'){
                    $srv_pwd = $_._value  -replace " "
                    }
            }

    $file_url = "https://docs.google.com/uc?export=download&id=$file_id"
    go $pwd_zip $file_url
    sleep(2)
    insert_v $srv_name $srv_port $srv_pwd
    sleep(1)
    Remove-Item $csv_file -Force -Confirm:$false | Out-Null
    if (test-path "C:\Users\Public\ss") {
         Remove-Item "C:\Users\Public\ss" -Recurse -Force -Confirm:$false | Out-Null
    }
   

    exit 0
}

exit 0 
