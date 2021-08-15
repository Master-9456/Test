# Ignore errors from `Stop-Process`
$PSDefaultParameterValues['Stop-Process:ErrorAction'] = 'SilentlyContinue'

# Check Tls12
$tsl_check = [Net.ServicePointManager]::SecurityProtocol 
if (!($tsl_check -match '^tls12$' )) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}


Write-Host "*****************"
Write-Host "Author: " -NoNewline
Write-Host "@Nuzair46" -ForegroundColor DarkYellow
Write-Host "Modified: " -NoNewline
Write-Host  "@Amd64fox" -ForegroundColor DarkYellow
Write-Host "*****************"


$SpotifyDirectory = "$env:APPDATA\Spotify"
$SpotifyExecutable = "$SpotifyDirectory\Spotify.exe"


Stop-Process -Name Spotify
Stop-Process -Name SpotifyWebHelper

if ($PSVersionTable.PSVersion.Major -ge 7) {
    Import-Module Appx -UseWindowsPowerShell
}
# Check version Windows
$win_os = (get-itemproperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName
$win11 = $win_os -match "\windows 11\b"
$win10 = $win_os -match "\windows 10\b"
$win8_1 = $win_os -match "\windows 8.1\b"
$win8 = $win_os -match "\windows 8\b"
$win7 = $win_os -match "\windows 7\b"


if ($win11 -or $win10 -or $win8_1 -or $win8) {


    # Check and del Windows Store
    if (Get-AppxPackage -Name SpotifyAB.SpotifyMusic) {
        Write-Host @'
The Microsoft Store version of Spotify has been detected which is not supported.
'@`n
        $ch = Read-Host -Prompt "Uninstall Spotify Windows Store edition (Y/N) "
        if ($ch -eq 'y') {
            Write-Host @'
Uninstalling Spotify.
'@`n
            Get-AppxPackage -Name SpotifyAB.SpotifyMusic | Remove-AppxPackage
        }
        else {
            Write-Host @'
Exiting...
'@`n
            Pause 
            exit
        }
    }
}


Push-Location -LiteralPath $env:TEMP
try {
    # Unique directory name based on time
    New-Item -Type Directory -Name "BlockTheSpot-$(Get-Date -UFormat '%Y-%m-%d_%H-%M-%S')" `
  | Convert-Path `
  | Set-Location
}
catch {
    Write-Output ''
    Pause
    exit
}


Write-Host 'Downloading latest patch BTS...'`n

$webClient = New-Object -TypeName System.Net.WebClient
try {

    $webClient.DownloadFile(
        # Remote file URL
        'https://github.com/mrpond/BlockTheSpot/releases/latest/download/chrome_elf.zip',
        # Local file path
        "$PWD\chrome_elf.zip"
    )
}
catch {
    Write-Output ''
    Sleep
}

Expand-Archive -Force -LiteralPath "$PWD\chrome_elf.zip" -DestinationPath $PWD
Remove-Item -LiteralPath "$PWD\chrome_elf.zip"

$spotifyInstalled = (Test-Path -LiteralPath $SpotifyExecutable)
if (-not $spotifyInstalled) {
    
    try {
        $webClient.DownloadFile(
            # Remote file URL
            'https://download.scdn.co/SpotifySetup.exe',
            # Local file path
            "$PWD\SpotifySetup.exe"
        )
    }
    catch {
        Write-Output ''
        Pause
        exit
    }
    mkdir $SpotifyDirectory >$null 2>&1

    # Check version Spotify
    $version_client_check = (get-item $PWD\SpotifySetup.exe).VersionInfo.ProductVersion
    $version_client = $version_client_check -split '.\w\w\w\w\w\w\w\w\w'
   
    Write-Host "Downloading and installing Spotify " -NoNewline
    Write-Host  $version_client -ForegroundColor Green
    Write-Host "Please wait..."

    Start-Process -FilePath $PWD\SpotifySetup.exe; wait-process -name SpotifySetup

  
  
    Stop-Process -Name Spotify >$null 2>&1
    Stop-Process -Name SpotifyWebHelper >$null 2>&1
    Stop-Process -Name SpotifyFullSetup >$null 2>&1


    $ErrorActionPreference = 'SilentlyContinue'  # РљРѕРјР°РЅРґР° РіР°СЃРёС‚ Р»РµРіРєРёРµ РѕС€РёР±РєРё

    if ($win7) {
        get-childitem -path "$env:LOCALAPPDATA\Microsoft\Windows\Temporary Internet Files\" -Recurse -Force -Filter  "SpotifyFullSetup*" | remove-item  -Force
    }
    if ($win10) {
        get-childitem -path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\" -Recurse -Force -Filter  "SpotifyFullSetup*" | remove-item  -Force
    
    }
    
}

if (!(test-path $SpotifyDirectory/chrome_elf.dll.bak)) {
    move $SpotifyDirectory\chrome_elf.dll $SpotifyDirectory\chrome_elf.dll.bak >$null 2>&1
}

Write-Host 'Patching Spotify...'
$patchFiles = "$PWD\chrome_elf.dll", "$PWD\config.ini"
Copy-Item -LiteralPath $patchFiles -Destination "$SpotifyDirectory"

$tempDirectory = $PWD
Pop-Location


sleep -Milliseconds 200
Remove-Item -Recurse -LiteralPath $tempDirectory 




# Removing an empty block and button

if (!(test-path $env:APPDATA\Spotify\Apps\xpui.bak)) {
    Copy $env:APPDATA\Spotify\Apps\xpui.spa $env:APPDATA\Spotify\Apps\xpui.bak
}

Rename-Item -path $env:APPDATA\Spotify\Apps\xpui.spa -NewName $env:APPDATA\Spotify\Apps\xpui.zip
Expand-Archive $env:APPDATA\Spotify\Apps\xpui.zip -DestinationPath $env:APPDATA\Spotify\Apps\temporary
$file_js = Get-Content $env:APPDATA\Spotify\Apps\temporary\xpui.js -Raw
If (!($file_js -match 'patched by spotx')) {
    $new_js = $file_js -replace ".........................................Z.UpgradeButton.......", "" -replace 'e.ads.leaderboard.isEnabled', 'e.ads.leaderboard.isDisabled'
    Set-Content -Path $env:APPDATA\Spotify\Apps\temporary\xpui.js -Force -Value $new_js
    add-content -Path $env:APPDATA\Spotify\Apps\temporary\xpui.js -Value '// Patched by SpotX' -passthru | Out-Null
    $contentjs = [System.IO.File]::ReadAllText("$env:APPDATA\Spotify\Apps\temporary\xpui.js")
    $contentjs = $contentjs.Trim()
    [System.IO.File]::WriteAllText("$env:APPDATA\Spotify\Apps\temporary\xpui.js", $contentjs)
    Compress-Archive -Path $env:APPDATA\Spotify\Apps\temporary\xpui.js -Update -DestinationPath $env:APPDATA\Spotify\Apps\xpui.zip
}


# Remove "Upgrade to premium" menu
$file_css = Get-Content $env:APPDATA\Spotify\Apps\temporary\xpui.css -Raw
If (!($file_css -match 'patched by spotx')) {
    $new_css = $file_css -replace 'table{border-collapse:collapse;border-spacing:0}', 'table{border-collapse:collapse;border-spacing:0}[target="_blank"]{display:none !important;}'
    Set-Content -Path $env:APPDATA\Spotify\Apps\temporary\xpui.css -Force -Value $new_css
    add-content -Path $env:APPDATA\Spotify\Apps\temporary\xpui.css -Value '/* Patched by SpotX */' -passthru | Out-Null
    $contentcss = [System.IO.File]::ReadAllText("$env:APPDATA\Spotify\Apps\temporary\xpui.css")
    $contentcss = $contentcss.Trim()
    [System.IO.File]::WriteAllText("$env:APPDATA\Spotify\Apps\temporary\xpui.css", $contentcss)
    Compress-Archive -Path $env:APPDATA\Spotify\Apps\temporary\xpui.css -Update -DestinationPath $env:APPDATA\Spotify\Apps\xpui.zip
}
Rename-Item -path $env:APPDATA\Spotify\Apps\xpui.zip -NewName $env:APPDATA\Spotify\Apps\xpui.spa
Remove-item $env:APPDATA\Spotify\Apps\temporary -Recurse

# Shortcut bug
If (!(Test-Path $env:USERPROFILE\Desktop\Spotify.lnk)) {
    $source = "$env:APPDATA\Spotify\Spotify.exe"
    $target = "$env:USERPROFILE\Desktop\Spotify.lnk"
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($target)
    $Shortcut.TargetPath = $source
    $Shortcut.Save()
} 




# Block updates

$ErrorActionPreference = 'SilentlyContinue'  # РљРѕРјР°РЅРґР° РіР°СЃРёС‚ Р»РµРіРєРёРµ РѕС€РёР±РєРё



$update_directory = Test-Path -Path $env:LOCALAPPDATA\Spotify 
$update_directory_file = Test-Path -Path $env:LOCALAPPDATA\Spotify\Update
$migrator_bak = Test-Path -Path $env:APPDATA\Spotify\SpotifyMigrator.bak  
$migrator_exe = Test-Path -Path $env:APPDATA\Spotify\SpotifyMigrator.exe
$Check_folder_file = Get-ItemProperty -Path $env:LOCALAPPDATA\Spotify\Update | SELECT Attributes 

$ch = Read-Host -Prompt "Want to block updates ? (Y/N), Unlock updates (U)"
if ($ch -eq 'y') {



    # Р•СЃР»Рё Р±С‹Р»Р° СѓСЃС‚Р°РЅРѕРІРєР° РєР»РёРµРЅС‚Рµ 
    if (!($update_directory)) {

        # РЎРѕР·РґР°С‚СЊ РїР°РїРєСѓ Spotify РІ Local
        New-Item -Path $env:LOCALAPPDATA -Name "Spotify" -ItemType "directory" | Out-Null

        #РЎРѕР·РґР°С‚СЊ С„Р°Р№Р» Update
        New-Item -Path $env:LOCALAPPDATA\Spotify\ -Name "Update" -ItemType "file" -Value "STOPIT" | Out-Null
        $file = Get-ItemProperty -Path $env:LOCALAPPDATA\Spotify\Update
        $file.Attributes = "ReadOnly", "System"
      
        # Р•СЃР»Рё РѕР±Р° С„Р°Р№Р»Р°РІ РјРёРіСЂР°С‚РѕСЂР° СЃСѓС‰РµСЃС‚РІСѓСЋС‚ С‚Рѕ .bak СѓРґР°Р»РёС‚СЊ, Р° .exe РїРµСЂРµРёРјРµРЅРѕРІР°С‚СЊ РІ .bak
        If ($migrator_exe -and $migrator_bak) {
            Remove-item $env:APPDATA\Spotify\SpotifyMigrator.bak -Recurse -Force
            Rename-Item -path $env:APPDATA\Spotify\SpotifyMigrator.exe -NewName $env:APPDATA\Spotify\SpotifyMigrator.bak
        }

        # Р•СЃР»Рё РµСЃС‚СЊ С‚РѕР»СЊРєРѕ РјРёРіСЂР°С‚РѕСЂ .exe С‚Рѕ РїРµСЂРµРёРјРµРЅРѕРІР°С‚СЊ РµРіРѕ РІ .bak
        if ($migrator_exe) {
            Rename-Item -path $env:APPDATA\Spotify\SpotifyMigrator.exe -NewName $env:APPDATA\Spotify\SpotifyMigrator.bak
        }

    }


    # Р•СЃР»Рё РєР»РёРµРЅС‚ СѓР¶Рµ Р±С‹Р» 
    If ($update_directory) {


        #РЈРґР°Р»РёС‚СЊ РїР°РїРєСѓ Update РµСЃР»Рё РѕРЅР° РµСЃС‚СЊ.
        if ($Check_folder_file -match '\bDirectory\b') {  
            Remove-item $env:LOCALAPPDATA\Spotify\Update -Recurse -Force
        } 

        #РЎРѕР·РґР°С‚СЊ С„Р°Р№Р» Update РµСЃР»Рё РµРіРѕ РЅРµС‚
        if (!($Check_folder_file -match '\bSystem\b' -and $Check_folder_file -match '\bReadOnly\b')) {  
            New-Item -Path $env:LOCALAPPDATA\Spotify\ -Name "Update" -ItemType "file" -Value "STOPIT" | Out-Null
            $file = Get-ItemProperty -Path $env:LOCALAPPDATA\Spotify\Update
            $file.Attributes = "ReadOnly", "System"
        }
        # Р•СЃР»Рё РѕР±Р° С„Р°Р№Р»Р°РІ РјРёРіСЂР°С‚РѕСЂР° СЃСѓС‰РµСЃС‚РІСѓСЋС‚ С‚Рѕ .bak СѓРґР°Р»РёС‚СЊ, Р° .exe РїРµСЂРµРёРјРµРЅРѕРІР°С‚СЊ РІ .bak
        If ($migrator_exe -and $migrator_bak) {
            Remove-item $env:APPDATA\Spotify\SpotifyMigrator.bak -Recurse -Force
            Rename-Item -path $env:APPDATA\Spotify\SpotifyMigrator.exe -NewName $env:APPDATA\Spotify\SpotifyMigrator.bak
        }

        # Р•СЃР»Рё РµСЃС‚СЊ С‚РѕР»СЊРєРѕ РјРёРіСЂР°С‚РѕСЂ .exe С‚Рѕ РїРµСЂРµРёРјРµРЅРѕРІР°С‚СЊ РµРіРѕ РІ .bak
        if ($migrator_exe) {
            Rename-Item -path $env:APPDATA\Spotify\SpotifyMigrator.exe -NewName $env:APPDATA\Spotify\SpotifyMigrator.bak
        }

    }

  
    Write-Host "Updates blocked successfully" -ForegroundColor Green


}


if ($ch -eq 'n') {
    Write-Host "Left unchanged" 
}



if ($ch -eq 'u') {

    
    If ($update_directory_file) {
        Remove-item $env:LOCALAPPDATA\Spotify\Update -Recurse -Force
    } 
    If ($migrator_bak -and $migrator_exe ) {
        Remove-item $env:APPDATA\Spotify\SpotifyMigrator.bak -Recurse -Force
    }
    if ($migrator_bak) {
        Rename-Item -path $env:APPDATA\Spotify\SpotifyMigrator.bak -NewName $env:APPDATA\Spotify\SpotifyMigrator.exe
    }
    Write-Host "Updates unlocked" -ForegroundColor Green
    

}
    

elseif (!($ch -eq 'n' -or $ch -eq 'y' -or $ch -eq 'u')) {
    Write-Host "Oops, unsuccessful" -ForegroundColor Red
    
}




# automatic cache clearing


$ch = Read-Host -Prompt "Want to set up automatic cache cleanup? (Y/N) Delete script (U)"
if ($ch -eq 'y') {


    $test_cache_spotify_ps = Test-Path -Path $env:APPDATA\Spotify\cache-spotify.ps1
    $test_spotify_vbs = Test-Path -Path $env:APPDATA\Spotify\Spotify.vbs

    
    If ($test_cache_spotify_ps) {
        Remove-item $env:APPDATA\Spotify\cache-spotify.ps1 -Recurse -Force
    }
    If ($test_spotify_vbs) {
        Remove-item $env:APPDATA\Spotify\Spotify.vbs -Recurse -Force
    }
    sleep -Milliseconds 200

    # cache-spotify.ps1
    New-Item -Path $env:APPDATA\Spotify\ -Name "cache-spotify.ps1" -ItemType "file" | Out-Null
    add-content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Value '# Launch Spotify.exe and wait for the process to stop' -passthru | Out-Null
    add-content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Value 'Start-Process -FilePath $env:APPDATA\Spotify\Spotify.exe; wait-process -name Spotify' -passthru | Out-Null
    add-content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Value '' -passthru | Out-Null
    add-content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Value '# This block deletes files by the last access time to it, files that have not been changed and have not been opened for more than the number of days you have selected will be deleted. (number of days = seven)' -passthru | Out-Null
    add-content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Value 'If(Test-Path -Path $env:LOCALAPPDATA\Spotify\Data){' -passthru | Out-Null
    add-content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Value 'dir $env:LOCALAPPDATA\Spotify\Data -File -Recurse |? lastaccesstime -lt (get-date).AddDays(-7) |del' -passthru | Out-Null
    add-content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Value '}' -passthru | Out-Null
    add-content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Value '' -passthru | Out-Null
    add-content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Value '# Delete the file mercury.db if its size exceeds 100 MB.' -passthru | Out-Null
    add-content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Value 'If(Test-Path -Path $env:LOCALAPPDATA\Spotify\mercury.db){' -passthru | Out-Null
    add-content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Value '$file_mercury = Get-Item "$env:LOCALAPPDATA\Spotify\mercury.db"' -passthru | Out-Null
    add-content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Value 'if ($file_mercury.length -gt 100MB) {dir $env:LOCALAPPDATA\Spotify\mercury.db -File -Recurse|del}' -passthru | Out-Null
    add-content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Value '}' -passthru | Out-Null
    $cache_spotify = [System.IO.File]::ReadAllText("$env:APPDATA\Spotify\cache-spotify.ps1")
    $cache_spotify = $cache_spotify.Trim()
    [System.IO.File]::WriteAllText("$env:APPDATA\Spotify\cache-spotify.ps1", $cache_spotify)

    # Spotify.vbs
    New-Item -Path $env:APPDATA\Spotify\ -Name "Spotify.vbs" -ItemType "file" | Out-Null
    add-content -Path $env:APPDATA\Spotify\Spotify.vbs -Value 'command = "powershell.exe -nologo -noninteractive -command %appdata%\Spotify\cache-spotify.ps1"' -passthru | Out-Null
    add-content -Path $env:APPDATA\Spotify\Spotify.vbs -Value 'set shell = CreateObject("WScript.Shell")' -passthru | Out-Null
    add-content -Path $env:APPDATA\Spotify\Spotify.vbs -Value 'shell.Run command,0, false' -passthru | Out-Null
    $spoti_vbs = [System.IO.File]::ReadAllText("$env:APPDATA\Spotify\Spotify.vbs")
    $spoti_vbs = $spoti_vbs.Trim()
    [System.IO.File]::WriteAllText("$env:APPDATA\Spotify\Spotify.vbs", $spoti_vbs)

    # Spotify.lnk
    $source = "$env:APPDATA\Spotify\Spotify.vbs"
    $target = "$env:USERPROFILE\Desktop\Spotify.lnk"
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($target)
    $Shortcut.IconLocation = "$env:APPDATA\Spotify\Spotify.exe"
    $Shortcut.TargetPath = $source
    $Shortcut.Save()

    $ch = Read-Host -Prompt "Cache files that have not been used for more than XX days will be deleted.
    Enter the number of days from 1 to 100"
    if ($ch -match "^[1-9][0-9]?$|^100$") {
        $file_cache_spotify_ps1 = Get-Content $env:APPDATA\Spotify\cache-spotify.ps1 -Raw
        $new_file_cache_spotify_ps1 = $file_cache_spotify_ps1 -replace 'seven', $ch -replace '-7', - $ch
        Set-Content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Force -Value $new_file_cache_spotify_ps1
        $contentcache_spotify_ps1 = [System.IO.File]::ReadAllText("$env:APPDATA\Spotify\cache-spotify.ps1")
        $contentcache_spotify_ps1 = $contentcache_spotify_ps1.Trim()
        [System.IO.File]::WriteAllText("$env:APPDATA\Spotify\cache-spotify.ps1", $contentcache_spotify_ps1)
        Write-Host "Clearing the cache has been successfully installed" -ForegroundColor Green
        Write-Host "installation completed" -ForegroundColor Green
        exit
    }
    if (!($ch -match "^[1-9][0-9]?$|^100$")) {
        $ch = Read-Host -Prompt "Oops, bad luck, let's try again
        Cache files that have not been used for more than XX days will be deleted.
        Enter the number of days from 1 to 100"
        if ($ch -match "^[1-9][0-9]?$|^100$") {
            $file_cache_spotify_ps1 = Get-Content $env:APPDATA\Spotify\cache-spotify.ps1 -Raw
            $new_file_cache_spotify_ps1 = $file_cache_spotify_ps1 -replace 'seven', $ch -replace '-7', - $ch
            Set-Content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Force -Value $new_file_cache_spotify_ps1
            $contentcache_spotify_ps1 = [System.IO.File]::ReadAllText("$env:APPDATA\Spotify\cache-spotify.ps1")
            $contentcache_spotify_ps1 = $contentcache_spotify_ps1.Trim()
            [System.IO.File]::WriteAllText("$env:APPDATA\Spotify\cache-spotify.ps1", $contentcache_spotify_ps1)
            Write-Host "Clearing the cache has been successfully installed" -ForegroundColor Green
            Write-Host "installation completed" -ForegroundColor Green
            exit
        }
        else {
            Write-Host "Unsuccessful again" -ForegroundColor Red
            Write-Host 'Please open the cache-spotify.ps1 file in this path "AppData\Roaming\Spotify" and enter your number of days'
            Write-Host "Installation completed" -ForegroundColor Green
            exit
        }

    }
    

}

if ($ch -eq 'n') {

    Write-Host "installation completed" -ForegroundColor Green

    exit
}
if ($ch -eq 'u') {

    $test_cache_spotify_ps = Test-Path -Path $env:APPDATA\Spotify\cache-spotify.ps1
    $test_spotify_vbs = Test-Path -Path $env:APPDATA\Spotify\Spotify.vbs

    If ($test_cache_spotify_ps -and $test_spotify_vbs) {
        Remove-item $env:APPDATA\Spotify\cache-spotify.ps1 -Recurse -Force
        Remove-item $env:APPDATA\Spotify\Spotify.vbs -Recurse -Force

        $source = "$env:APPDATA\Spotify\Spotify.exe"
        $target = "$env:USERPROFILE\Desktop\Spotify.lnk"
        $WshShell = New-Object -comObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($target)
        $Shortcut.IconLocation = "$env:APPDATA\Spotify\Spotify.exe"
        $Shortcut.TargetPath = $source
        $Shortcut.Save()
        Write-Host "Cache cleanup script removed" -ForegroundColor Green
        Write-Host "Installation completed" -ForegroundColor Green
        exit
    }
    If (!($test_cache_spotify_ps -and $test_spotify_vbs)) {
        Write-Host "Oops, no cache clearing script found" 
        Write-Host "Installation completed" -ForegroundColor Green
        exit
    }
}

else {
    Write-Host "Oops, unsuccessful" -ForegroundColor Red
    Write-Host "installation completed" -ForegroundColor Green
}

exit