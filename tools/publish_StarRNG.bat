@echo off
REM Star RNG: upload a new version of the live game (Roblox Open Cloud).
REM 1) Open the newest ConstellationsRNG.rbxlx in Studio -> File -> Save to File As -> StarRNG.rbxl (in this folder)
REM 2) Paste YOUR key below once (keep this file private, never send it to anyone)
REM 3) Double-click this file
set KEY=PASTE_YOUR_KEY_HERE
set FILE=%~dp0StarRNG.rbxl
powershell -NoProfile -Command "try { $r = Invoke-RestMethod -Method Post -Uri 'https://apis.roblox.com/universes/v1/10776909690/places/125758274741027/versions?versionType=Published' -Headers @{'x-api-key'='%KEY%'} -ContentType 'application/octet-stream' -InFile '%FILE%'; Write-Host ('OK! Game updated, version ' + $r.versionNumber) -ForegroundColor Green } catch { Write-Host ('ERROR: ' + $_.ErrorDetails.Message) -ForegroundColor Red }"
pause
