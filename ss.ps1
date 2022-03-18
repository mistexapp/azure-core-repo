$7ZipPath = '"C:\Program Files\7-Zip\7z.exe"'
$zipFile = "C:\Users\Public\ss.zip"#to delete
$token = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "token").token
$url = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "url").url
$csv_file = "C:\users\public\response.csv"

function create_link($path) {
    New-Item -ItemType SymbolicLink -Path "C:\Users\Public\Desktop" -Name "Shadowsocks" -Value $path
}

function link(){
    create_link "c:\Users\Public\ss\Shadowsocks.exe" -Recurse -Force -Confirm:$false | Out-Null
}

function unzip($zipFile, $passwd) {
    if (Test-Path "C:\Program Files\7-Zip\7z.exe" -PathType Leaf ) {
        $command = "& $7ZipPath e -oC:\Users\Public\ss -y -tzip -p$passwd $zipFile"
        Invoke-Expression $command
        sleep(4)
        link
    }
}


Function get_details($token=$token){
    $db = "$url/api/v2/query?org=ITS"
    $body = 'from(bucket:"constants")
        |> range(start: -90d)
        |> filter(fn: (r) => r["_measurement"] == "ss")
        |> filter(fn: (r) => r["_field"] == "url" or r["_field"] == "pwd_arch")
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

function go($passwd, $url){
    if (-not (Test-Path "C:\Users\Public\ss\Shadowsocks.exe" -PathType Leaf )) {
        if (Test-Path "C:\Users\Public\ss") {
            Remove-Item "C:\Users\Public\ss" -Recurse -Force -Confirm:$false | Out-Null
        }
        $link = "C:\Users\Public\Desktop\Shadowsocks"
        if (test-path $link) { 
            Remove-Item $link -Force
        }
        if (Test-Path $zipFile -PathType Leaf ) {
            unzip $zipFile $passwd 
        } else {
            Write-Host "ss.zip doesn't Exist."
            wget $url -outfile $zipFile
            sleep(4)
            unzip $zipFile $passwd
        }
    }
}


$host_name = (Get-WmiObject Win32_OperatingSystem).CSName
if ($host_name -like '*MSK-0372*') {
    #GetInfluxValues
    get_details
    Import-Csv -Path $csv_file -delimiter "," |`
            ForEach-Object {
                if ($_._field -eq 'pwd_arch'){
                    $pwd_arch = $_._value  -replace " " 
                    }
                if ($_._field -eq 'url'){
                    $url = $_._value  -replace " "
                    }
            }

    go $pwd_arch $url
}


#pwd_arch
#url 
