<#
    _send

    for sending data.
#>

function _send($m) {
  $token = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "token").token
  $url = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "url").url
  $bucket = 'prod-db-sept'
  
  Function fuuu($t, $u, $m){
    Invoke-RestMethod -Headers @{
        "Authorization" = "Token $t"
        "Content-Type" = "text/plain; charset=utf-8"
        "Accept" = "application/json"
        } `
                    -Method POST `
                    -Uri  $u `
                    -Body $m
  }
  
  fuuu $token "$url/api/v2/write?org=ITS&bucket=$bucket&precision=s" $m
} 
