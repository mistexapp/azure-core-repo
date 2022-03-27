<#
    _send

    for sending data.
#>

function _send($project, $obj) {
  $token = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "token").token
  $url = (Get-ItemProperty -Path "HKLM:\SOFTWARE\ITSupport\" -Name "url").url
  $bucket = 'prod-db-sept'
  
  $obj | Format-List
  $m = "{0},host={1} " -f $project, $obj.serialnumber
  foreach ($x in ($obj | Get-Member -MemberType NoteProperty) | Select-Object -ExpandProperty Name) {
      $string1 = '{0}="{1}",' -f $x, $obj.$x
      $m += $string1
  }
  $m = $m.Substring(0,$m.Length-1)
  $m += " {0}" -f $_check.timestamp
  
  Function fuuu($t, $u, $m){
    $headers = @{
        "Authorization" = "Token $t"
        "Content-Type" = "text/plain; charset=utf-8"
        "Accept" = "application/json"
    }

    try {
        $result = Invoke-WebRequest -Uri $u -Method Post -Headers $headers -Body $m
        Write-Host "StatusCode: "$result.StatusCode
    } catch [System.InvalidOperationException] {}
  }
  
  fuuu $token "$url/api/v2/write?org=ITS&bucket=$bucket&precision=s" $m
}
