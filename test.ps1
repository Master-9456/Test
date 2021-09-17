# Ignore errors from `Stop-Process`
$PSDefaultParameterValues['Stop-Process:ErrorAction'] = 'SilentlyContinue'

# Check Tls12
$tsl_check = [Net.ServicePointManager]::SecurityProtocol 
if (!($tsl_check -match '^tls12$' )) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}


Write-Host "*****************"
Write-Host "Author: " -NoNewline
Write-Host "@amd64fox" -ForegroundColor DarkYellow
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
    Start-Sleep
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


    $ErrorActionPreference = 'SilentlyContinue'  # Команда гасит легкие ошибки

    # Удалить инсталятор после установки
    if ($win8 -or $win7) {
        get-childitem -path "$env:LOCALAPPDATA\Microsoft\Windows\Temporary Internet Files\" -Recurse -Force -Filter  "SpotifyFullSetup*" | remove-item  -Force
    }
    if ($win11 -or $win10 -or $win8_1) {
        get-childitem -path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\" -Recurse -Force -Filter  "SpotifyFullSetup*" | remove-item  -Force
    
    }
    
}

if (!(test-path $SpotifyDirectory/chrome_elf.dll.bak)) {
    Move-Item $SpotifyDirectory\chrome_elf.dll $SpotifyDirectory\chrome_elf.dll.bak >$null 2>&1
}

Write-Host 'Patching Spotify...'
$patchFiles = "$PWD\chrome_elf.dll", "$PWD\config.ini"
Copy-Item -LiteralPath $patchFiles -Destination "$SpotifyDirectory"

$tempDirectory = $PWD
Pop-Location


Start-Sleep -Milliseconds 200
Remove-Item -Recurse -LiteralPath $tempDirectory 




# Removing an empty block, "Upgrade button", "Upgrade to premium" menu

Rename-Item -path $env:APPDATA\Spotify\Apps\xpui.spa -NewName $env:APPDATA\Spotify\Apps\xpui.zip
if (Test-Path $env:APPDATA\Spotify\Apps\temporary) {
    Remove-item $env:APPDATA\Spotify\Apps\temporary -Recurse
}
New-Item -Path $env:APPDATA\Spotify\Apps\temporary -ItemType Directory | Out-Null

# Достаем из архива 2 файла
$shell = New-Object -Com Shell.Application 
$shell.NameSpace("$(resolve-path $env:APPDATA\Spotify\Apps\xpui.zip)").Items() | Where-Object Name -eq "xpui.js" | Where-Object {
    $shell.NameSpace("$env:APPDATA\Spotify\Apps\temporary").copyhere($_) } 
$shell.NameSpace("$(resolve-path $env:APPDATA\Spotify\Apps\xpui.zip)").Items() | Where-Object Name -eq "xpui-routes-offline-browse.css" | Where-Object {
    $shell.NameSpace("$env:APPDATA\Spotify\Apps\temporary").copyhere($_) } 



# Делает резервную копию xpui.spa, также если бейкап устарел то заменяет старую на новую версию
$xpui_js_last_write_time = Get-ChildItem $env:APPDATA\Spotify\Apps\temporary\xpui.js -File -Recurse
$xpui_licenses_last_write_time = Get-ChildItem $env:APPDATA\Spotify\Apps\temporary\xpui-routes-offline-browse.css -File -Recurse

if ($xpui_licenses_last_write_time.LastWriteTime -eq $xpui_js_last_write_time.LastWriteTime) {

    if (test-path $env:APPDATA\Spotify\Apps\xpui.bak) {
        Remove-item $env:APPDATA\Spotify\Apps\xpui.bak -Recurse
    }
    Copy-Item $env:APPDATA\Spotify\Apps\xpui.zip $env:APPDATA\Spotify\Apps\xpui.bak
}


$file_js = Get-Content $env:APPDATA\Spotify\Apps\temporary\xpui.js -Raw
If (!($file_js -match 'patched by spotx')) {
    $file_js -match 'visible:!e}[)]{1}[,]{1}[A-Za-z]{1}[(]{1}[)]{1}.createElement[(]{1}[A-Za-z]{2}[,]{1}null[)]{1}[,]{1}[A-Za-z]{1}[(]{1}[)]{1}.' | Out-Null
    $menu_split_js = $Matches[0] -split 'createElement[(]{1}[A-Za-z]{2}[,]{1}null[)]{1}[,]{1}[A-Za-z]{1}[(]{1}[)]{1}.'
    $new_js = $file_js -replace "[.]{1}createElement[(]{1}..[,]{1}[{]{1}onClick[:]{1}.[,]{1}className[:]{1}..[.]{1}.[.]{1}UpgradeButton[}]{1}[)]{1}[,]{1}.[(]{1}[)]{1}", "" -replace 'adsEnabled:!0', 'adsEnabled:!1' -replace 'visible:!e}[)]{1}[,]{1}[A-Za-z]{1}[(]{1}[)]{1}.createElement[(]{1}[A-Za-z]{2}[,]{1}null[)]{1}[,]{1}[A-Za-z]{1}[(]{1}[)]{1}.', $menu_split_js
    Set-Content -Path $env:APPDATA\Spotify\Apps\temporary\xpui.js -Force -Value $new_js
    add-content -Path $env:APPDATA\Spotify\Apps\temporary\xpui.js -Value '// Patched by SpotX' -passthru | Out-Null
    $contentjs = [System.IO.File]::ReadAllText("$env:APPDATA\Spotify\Apps\temporary\xpui.js")
    $contentjs = $contentjs.Trim()
    [System.IO.File]::WriteAllText("$env:APPDATA\Spotify\Apps\temporary\xpui.js", $contentjs)
    Compress-Archive -Path $env:APPDATA\Spotify\Apps\temporary\xpui.js -Update -DestinationPath $env:APPDATA\Spotify\Apps\xpui.zip
}


<#
# Удаление меню (РЕЗЕРВНЫЙ)
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
#>


Rename-Item -path $env:APPDATA\Spotify\Apps\xpui.zip -NewName $env:APPDATA\Spotify\Apps\xpui.spa
Remove-item $env:APPDATA\Spotify\Apps\temporary -Recurse



# Shortcut bug
$ErrorActionPreference = 'SilentlyContinue' 

If (!(Test-Path $env:USERPROFILE\Desktop\Spotify.lnk)) {
  
    $source = "$env:APPDATA\Spotify\Spotify.exe"
    $target = "$env:USERPROFILE\Desktop\Spotify.lnk"
    $WorkingDir = "$env:APPDATA\Spotify"
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($target)
    $Shortcut.WorkingDirectory = $WorkingDir
    $Shortcut.TargetPath = $source
    $Shortcut.Save()      
}




# Block updates

$ErrorActionPreference = 'SilentlyContinue'  # Команда гасит легкие ошибки



$update_directory = Test-Path -Path $env:LOCALAPPDATA\Spotify 
$update_directory_file = Test-Path -Path $env:LOCALAPPDATA\Spotify\Update
$migrator_bak = Test-Path -Path $env:APPDATA\Spotify\SpotifyMigrator.bak  
$migrator_exe = Test-Path -Path $env:APPDATA\Spotify\SpotifyMigrator.exe
$Check_folder_file = Get-ItemProperty -Path $env:LOCALAPPDATA\Spotify\Update | Select-Object Attributes 

$ch = Read-Host -Prompt "Want to block updates ? (Y/N), Unlock updates (U)"
if ($ch -eq 'y') {



    # Если была установка клиенте 
    if (!($update_directory)) {

        # Создать папку Spotify в Local
        New-Item -Path $env:LOCALAPPDATA -Name "Spotify" -ItemType "directory" | Out-Null

        #Создать файл Update
        New-Item -Path $env:LOCALAPPDATA\Spotify\ -Name "Update" -ItemType "file" -Value "STOPIT" | Out-Null
        $file = Get-ItemProperty -Path $env:LOCALAPPDATA\Spotify\Update
        $file.Attributes = "ReadOnly", "System"
      
        # Если оба файлав мигратора существуют то .bak удалить, а .exe переименовать в .bak
        If ($migrator_exe -and $migrator_bak) {
            Remove-item $env:APPDATA\Spotify\SpotifyMigrator.bak -Recurse -Force
            Rename-Item -path $env:APPDATA\Spotify\SpotifyMigrator.exe -NewName $env:APPDATA\Spotify\SpotifyMigrator.bak
        }

        # Если есть только мигратор .exe то переименовать его в .bak
        if ($migrator_exe) {
            Rename-Item -path $env:APPDATA\Spotify\SpotifyMigrator.exe -NewName $env:APPDATA\Spotify\SpotifyMigrator.bak
        }

    }


    # Если клиент уже был 
    If ($update_directory) {


        #Удалить папку Update если она есть.
        if ($Check_folder_file -match '\bDirectory\b') {  
            Remove-item $env:LOCALAPPDATA\Spotify\Update -Recurse -Force
        } 

        #Создать файл Update если его нет
        if (!($Check_folder_file -match '\bSystem\b' -and $Check_folder_file -match '\bReadOnly\b')) {  
            New-Item -Path $env:LOCALAPPDATA\Spotify\ -Name "Update" -ItemType "file" -Value "STOPIT" | Out-Null
            $file = Get-ItemProperty -Path $env:LOCALAPPDATA\Spotify\Update
            $file.Attributes = "ReadOnly", "System"
        }
        # Если оба файлав мигратора существуют то .bak удалить, а .exe переименовать в .bak
        If ($migrator_exe -and $migrator_bak) {
            Remove-item $env:APPDATA\Spotify\SpotifyMigrator.bak -Recurse -Force
            Rename-Item -path $env:APPDATA\Spotify\SpotifyMigrator.exe -NewName $env:APPDATA\Spotify\SpotifyMigrator.bak
        }

        # Если есть только мигратор .exe то переименовать его в .bak
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

    If ($migrator_bak -and $Check_folder_file -match '\bSystem\b' -and $Check_folder_file -match '\bReadOnly\b') {
       
    
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


    If (!($migrator_bak -and $Check_folder_file -match '\bSystem\b' -and $Check_folder_file -match '\bReadOnly\b')) {
        Write-Host "Oops, updates are not blocked" 
    }  
}
    

elseif (!($ch -eq 'n' -or $ch -eq 'y' -or $ch -eq 'u')) {
    Write-Host "Oops, unsuccessful" -ForegroundColor Red
    
}



# automatic cache clearing


$ch = Read-Host -Prompt "Want to set up automatic cache cleanup? (Y/N) Delete script (U)"
if ($ch -eq 'y') {


    $test_cache_spotify_ps = Test-Path -Path $env:APPDATA\Spotify\cache-spotify.ps1
    $test_spotify_vbs = Test-Path -Path $env:APPDATA\Spotify\Spotify.vbs
    $desktop_folder = Get-ItemProperty -Path $env:USERPROFILE\Desktop | Select-Object Attributes 
    

    # Если папки по умолчанию Dekstop не существует, то установку кэша отменить.
    if ($desktop_folder -match '\bDirectory\b') {  



        If ($test_cache_spotify_ps) {
            Remove-item $env:APPDATA\Spotify\cache-spotify.ps1 -Recurse -Force
        }
        If ($test_spotify_vbs) {
            Remove-item $env:APPDATA\Spotify\Spotify.vbs -Recurse -Force
        }
        Start-Sleep -Milliseconds 200


        # cache-spotify.ps1
        $webClient.DownloadFile('https://raw.githubusercontent.com/amd64fox/SpotX/main/cache-spotify.ps1', "$env:APPDATA\Spotify\cache-spotify.ps1")

        # Spotify.vbs
        $webClient.DownloadFile('https://raw.githubusercontent.com/amd64fox/SpotX/main/Spotify.vbs', "$env:APPDATA\Spotify\Spotify.vbs")


        # Spotify.lnk
        $source2 = "$env:APPDATA\Spotify\Spotify.vbs"
        $target2 = "$env:USERPROFILE\Desktop\Spotify.lnk"
        $WorkingDir2 = "$env:APPDATA\Spotify"
        $WshShell2 = New-Object -comObject WScript.Shell
        $Shortcut2 = $WshShell2.CreateShortcut($target2)
        $Shortcut2.WorkingDirectory = $WorkingDir2
        $Shortcut2.IconLocation = "$env:APPDATA\Spotify\Spotify.exe"
        $Shortcut2.TargetPath = $source2
        $Shortcut2.Save()


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
    else {
        Write-Host "Error, i can't find the 'Desktop' folder" -ForegroundColor Red
        Write-Host "Installation completed" -ForegroundColor Green
    
        Exit
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

        $source3 = "$env:APPDATA\Spotify\Spotify.exe"
        $target3 = "$env:USERPROFILE\Desktop\Spotify.lnk"
        $WorkingDir3 = "$env:APPDATA\Spotify"
        $WshShell3 = New-Object -comObject WScript.Shell
        $Shortcut3 = $WshShell3.CreateShortcut($target3)
        $Shortcut3.WorkingDirectory = $WorkingDir3
        $Shortcut3.IconLocation = "$env:APPDATA\Spotify\Spotify.exe"
        $Shortcut3.TargetPath = $source3
        $Shortcut3.Save()
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
