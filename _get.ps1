<#
    _get

    for getting values from influx
    
    ______________ How to use _______________
    |   . "$PSScriptRoot\_get.ps1"          |
    |   $some = _get "measurement" "field"  |
    |_______________________________________|
#>

Function _get {
    param (
    [Parameter(Mandatory=$true)]  
            $measurement,
            $field,
            $range="-365d"
            
    )
    $csv_file = "C:\users\public\_get.csv"
    $bucket = 'constants'
    $token=(Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "token").token 
    $raw_url=(Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "url").url
    $db = "$raw_url/api/v2/query?org=ITS"
    $body = 'from(bucket:"{0}")
        |> range(start: {1})
        |> filter(fn: (r) => r["_measurement"] == "{2}")
        |> last()
        |> drop(columns: ["_time", "_start", "_stop", "_result", "_measurement"])' -f $bucket, $range, $measurement
    

    function return_value {
        Invoke-RestMethod -Headers @{
            "Authorization" = "Token $token"
            "Content-Type" = "application/vnd.flux"
            "Accept" = "application/csv"
            } `
                    -Method POST `
                    -Uri $db `
                    -Body $body `
                    > $csv_file

        Import-Csv -Path $csv_file -delimiter "," |`
            ForEach-Object {
                if ($_._field -eq $field){
                    $value = $_._value  -replace " "
                }
            }
        $value
    }

    if (Test-Path -PathType Leaf $csv_file) {
        Remove-Item $csv_file -Force -Confirm:$false | Out-Null
    }
    
    $value = return_value
    $value
} 