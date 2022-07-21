. "$PSScriptRoot\_get.ps1"
$gt = _get "gt" "tok"


$headers = @{ "PRIVATE-TOKEN" = "$gt" }
$uri_priv_script = "https://mimimi.ninja/api/v4/projects/1405/repository/archive.zip"
$dir = "c:\Windows\Temp\ITS"
if (Test-Path $dir) {Remove-Item -Path $dir -Recurse -Force -Confirm:$false}
New-Item -ItemType Directory -Path $dir -Force | Out-Null
Invoke-WebRequest -Uri $uri_priv_script -Headers $headers -OutFile "$dir\scr.zip"
Expand-Archive -Path "$dir\scr.zip" -DestinationPath $dir -Force
Remove-Item -Path "$dir\scr.zip" -Force -Confirm:$false

Get-ChildItem $dir | Rename-Item -NewName "new_core_tmp"
Powershell.exe -executionpolicy remotesigned -File "$dir\new_core_tmp\aad_core.ps1"
Start-Sleep 3
Remove-Item -Path $dir -Recurse -Force -Confirm:$false