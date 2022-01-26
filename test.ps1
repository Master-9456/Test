# Игнорировать ошибки из `Stop-Process`
$PSDefaultParameterValues['Stop-Process:ErrorAction'] = [System.Management.Automation.ActionPreference]::SilentlyContinue


Write-Host "*****************"
Write-Host "Автор: " -NoNewline
Write-Host "@Amd64fox" -ForegroundColor DarkYellow
Write-Host "*****************"`n

$spotifyDirectory = "$env:APPDATA\Spotify"
$spotifyExecutable = "$spotifyDirectory\Spotify.exe"
$chrome_elf = "$spotifyDirectory\chrome_elf.dll"
$chrome_elf_bak = "$spotifyDirectory\chrome_elf_bak.dll"
$upgrade_client = $false
$podcasts_off = $false
$spotx_new = $false
$run_as_admin = $false
$block_update = $false
$cache_install = $false


# чек сертификата Tls12
$tsl_check = [Net.ServicePointManager]::SecurityProtocol 
if (!($tsl_check -match '^tls12$' )) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# Проверка прав запуска
[System.Security.Principal.WindowsPrincipal] $principal = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$isUserAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isUserAdmin) {
    Write-Host 'Обнаружен запуск с правами администратора'`n
    $run_as_admin = $true
}


Stop-Process -Name Spotify
Stop-Process -Name SpotifyWebHelper

if ($PSVersionTable.PSVersion.Major -ge 7) {
    Import-Module Appx -UseWindowsPowerShell
}
# Проверка версии Windows
$win_os = (get-itemproperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName
$win11 = $win_os -match "\windows 11\b"
$win10 = $win_os -match "\windows 10\b"
$win8_1 = $win_os -match "\windows 8.1\b"
$win8 = $win_os -match "\windows 8\b"


if ($win11 -or $win10 -or $win8_1 -or $win8) {


    # Удалить Spotify Windows Store если он есть
    if (Get-AppxPackage -Name SpotifyAB.SpotifyMusic) {
        Write-Host 'Обнаружена версия Spotify из Microsoft Store, которая не поддерживается.'`n
        $ch = Read-Host -Prompt "Хотите удалить Spotify Microsoft Store ? (Y/N) "
        if ($ch -eq 'y') {
            Write-Host 'Удаление Spotify.'`n
            Get-AppxPackage -Name SpotifyAB.SpotifyMusic | Remove-AppxPackage
        }
        else {
            Read-Host "Завершение работы...`nНажмите любую клавишу для выхода..." 
            exit
        }
    }
}

# Создаем уникальное имя каталога на основе времени
Push-Location -LiteralPath $env:TEMP
New-Item -Type Directory -Name "BlockTheSpot-$(Get-Date -UFormat '%Y-%m-%d_%H-%M-%S')" | Convert-Path | Set-Location


Write-Host 'Загружаю последний патч BTS...'`n

$webClient = New-Object -TypeName System.Net.WebClient
try {
    $webClient.DownloadFile(
        # Remote file URL
        "https://github.com/mrpond/BlockTheSpot/releases/latest/download/chrome_elf.zip",
        # Local file path
        "$PWD\chrome_elf.zip"
    )
}
catch [System.Management.Automation.MethodInvocationException] {
    Write-Host "Ошибка загрузки chrome_elf.zip" -ForegroundColor RED
    $Error[0].Exception
    Write-Host ""
    Write-Host "Повторный запрос через 5 секунд..."`n
    Start-Sleep -Milliseconds 5000 
    try {

        $webClient.DownloadFile(
            # Remote file URL
            "https://github.com/mrpond/BlockTheSpot/releases/latest/download/chrome_elf.zip",
            # Local file path
            "$PWD\chrome_elf.zip"
        )
    }
    catch [System.Management.Automation.MethodInvocationException] {
        Write-Host "Опять ошибка, скрипт остановлен" -ForegroundColor RED
        $Error[0].Exception
        Write-Host ""
        Write-Host "Попробуйте проверить подключение к интернету и снова запустить установку."`n
        $tempDirectory = $PWD
        Pop-Location
        Start-Sleep -Milliseconds 200
        Remove-Item -Recurse -LiteralPath $tempDirectory 
        exit
    }
}

Expand-Archive -Force -LiteralPath "$PWD\chrome_elf.zip" -DestinationPath $PWD
Remove-Item -LiteralPath "$PWD\chrome_elf.zip"



try {
    $webClient.DownloadFile(
        # Remote file URL
        'https://download.scdn.co/SpotifySetup.exe',
        # Local file path
        "$PWD\SpotifySetup.exe"
    )
}
catch [System.Management.Automation.MethodInvocationException] {
    Write-Host "Ошибка загрузки SpotifySetup.exe" -ForegroundColor RED
    $Error[0].Exception
    Write-Host ""
    Write-Host "Повторный запрос через 5 секунд..."`n
    Start-Sleep -Milliseconds 5000 
    try {

        $webClient.DownloadFile(
            # Remote file URL
            'https://download.scdn.co/SpotifySetup.exe',
            # Local file path
            "$PWD\SpotifySetup.exe"
        )
    }
    catch [System.Management.Automation.MethodInvocationException] {
        Write-Host "Опять ошибка, скрипт остановлен" -ForegroundColor RED
        $Error[0].Exception
        Write-Host ""
        Write-Host "Попробуйте проверить подключение к интернету и снова запустить установку."`n
        $tempDirectory = $PWD
        Pop-Location
        Start-Sleep -Milliseconds 200
        Remove-Item -Recurse -LiteralPath $tempDirectory 
        exit
    }
}



$spotifyInstalled = (Test-Path -LiteralPath $spotifyExecutable)

if ($spotifyInstalled) {



    # Проверка последней версии Spotify онлайн
    $version_client_check = (get-item $PWD\SpotifySetup.exe).VersionInfo.ProductVersion
    $online_version = $version_client_check -split '.\w\w\w\w\w\w\w\w\w'


    # Проверка последней версии Spotify офлайн
    $ofline_version = (Get-Item $spotifyExecutable).VersionInfo.FileVersion


    if ($online_version -gt $ofline_version) {


        do {
            $ch = Read-Host -Prompt "Ваша версия Spotify $ofline_version устарела, рекомендуется обновиться до $online_version `nОбновить ? (Y/N)"
            Write-Output $_
            if (!($ch -eq 'n' -or $ch -eq 'y')) {

                Write-Host "Oops, an incorrect value, " -ForegroundColor Red -NoNewline
                Write-Host "enter again through..." -NoNewline
                Start-Sleep -Milliseconds 1000
                Write-Host "3" -NoNewline
                Start-Sleep -Milliseconds 1000
                Write-Host ".2" -NoNewline
                Start-Sleep -Milliseconds 1000
                Write-Host ".1"
                Start-Sleep -Milliseconds 1000     
                Clear-Host
            }
        }
        while ($ch -notmatch '^y$|^n$')
        if ($ch -eq 'y') { $upgrade_client = $true }
    }
}


# Если клиента нет или он устарел, то начинаем установку

if (-not $spotifyInstalled -or $upgrade_client) {

    $version_client_check = (get-item $PWD\SpotifySetup.exe).VersionInfo.ProductVersion
    $version_client = $version_client_check -split '.\w\w\w\w\w\w\w\w\w'

    Write-Host "Загружаю и устанавливаю Spotify " -NoNewline
    Write-Host  $version_client -ForegroundColor Green
    Write-Host "Пожалуйста подождите......"`n


    # Исправление ошибки, если установщик Spotify был запущен от администратора

    if ($run_as_admin) {
        $apppath = 'powershell.exe'
        $taskname = 'Spotify install'
        $action = New-ScheduledTaskAction -Execute $apppath -Argument "-NoLogo -NoProfile -Command & `'$PWD\SpotifySetup.exe`'" 
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date)
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -WakeToRun
        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskname -Settings $settings -Force | Write-Verbose
        Start-ScheduledTask -TaskName $taskname
        Start-Sleep -Seconds 2
        Unregister-ScheduledTask -TaskName $taskname -Confirm:$false
        Start-Sleep -Seconds 2
        wait-process -name SpotifySetup
    }
    else {
        Start-Process -FilePath $PWD\SpotifySetup.exe; wait-process -name SpotifySetup
    }

    Stop-Process -Name Spotify 
    Stop-Process -Name SpotifyWebHelper 
    Stop-Process -Name SpotifyFullSetup 


    $ErrorActionPreference = 'SilentlyContinue'  # # Команда гасит легкие ошибки

    # Обновить резервную копию chrome_elf.dll
    if (Test-Path -LiteralPath $chrome_elf_bak) {
        Remove-item $spotifyDirectory/chrome_elf_bak.dll
        Move-Item $chrome_elf $chrome_elf_bak 
    }

    # Удалите установщик Spotify
    if (test-path "$env:LOCALAPPDATA\Microsoft\Windows\Temporary Internet Files\") {
        get-childitem -path "$env:LOCALAPPDATA\Microsoft\Windows\Temporary Internet Files\" -Recurse -Force -Filter  "SpotifyFullSetup*" | remove-item  -Force
    }
    if (test-path $env:LOCALAPPDATA\Microsoft\Windows\INetCache\) {
        get-childitem -path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\" -Recurse -Force -Filter  "SpotifyFullSetup*" | remove-item  -Force
    }
}


# Создать резервную копию chrome_elf.dll
if (!(Test-Path -LiteralPath $chrome_elf_bak)) {
    Move-Item $chrome_elf $chrome_elf_bak 
}



do {
    $ch = Read-Host -Prompt "Хотите отключить подкасты ? (Y/N)"
    Write-Host ""
    if (!($ch -eq 'n' -or $ch -eq 'y')) {
    
        Write-Host "Ой, некорректное значение, " -ForegroundColor Red -NoNewline
        Write-Host "повторите ввод через..." -NoNewline
        Start-Sleep -Milliseconds 1000
        Write-Host "3" -NoNewline
        Start-Sleep -Milliseconds 1000
        Write-Host ".2" -NoNewline
        Start-Sleep -Milliseconds 1000
        Write-Host ".1"
        Start-Sleep -Milliseconds 1000     
        Clear-Host
    }
}
while ($ch -notmatch '^y$|^n$')
if ($ch -eq 'y') { $podcasts_off = $true }


do {
    $ch = Read-Host -Prompt "Хотите заблокировать обновления ? (Y/N)"
    Write-Host ""
    if (!($ch -eq 'n' -or $ch -eq 'y')) {
    
        Write-Host "Ой, некорректное значение, " -ForegroundColor Red -NoNewline
        Write-Host "повторите ввод через..." -NoNewline
        Start-Sleep -Milliseconds 1000
        Write-Host "3" -NoNewline
        Start-Sleep -Milliseconds 1000
        Write-Host ".2" -NoNewline
        Start-Sleep -Milliseconds 1000
        Write-Host ".1"
        Start-Sleep -Milliseconds 1000     
        Clear-Host
    }
}
while ($ch -notmatch '^y$|^n$')

if ($ch -eq 'y') { $block_update = $true }

do {
    $ch = Read-Host -Prompt "Хотите установить автоматическую очистку кеша ? (Y/N)"
    Write-Host ""
    if (!($ch -eq 'n' -or $ch -eq 'y')) {
        Write-Host "Ой, некорректное значение, " -ForegroundColor Red -NoNewline
        Write-Host "повторите ввод через..." -NoNewline
        Start-Sleep -Milliseconds 1000
        Write-Host "3" -NoNewline
        Start-Sleep -Milliseconds 1000
        Write-Host ".2" -NoNewline
        Start-Sleep -Milliseconds 1000
        Write-Host ".1"
        Start-Sleep -Milliseconds 1000     
        Clear-Host
    }
}
while ($ch -notmatch '^y$|^n$')
if ($ch -eq 'y') {
    $cache_install = $true 

    do {
        $ch = Read-Host -Prompt "Файлы кэша, которые не использовались более XX дней, будут удалены.
    Пожалуйста, введите количество дней от 1 до 100"
        Write-Host ""
        if (!($ch -match "^[1-9][0-9]?$|^100$")) {
            Write-Host "Ой, некорректное значение, " -ForegroundColor Red -NoNewline
            Write-Host "повторите ввод через..." -NoNewline
		
            Start-Sleep -Milliseconds 1000
            Write-Host "3" -NoNewline
            Start-Sleep -Milliseconds 1000
            Write-Host ".2" -NoNewline
            Start-Sleep -Milliseconds 1000
            Write-Host ".1"
            Start-Sleep -Milliseconds 1000     
            Clear-Host
        }
    }
    while ($ch -notmatch '^[1-9][0-9]?$|^100$')

    if ($ch -match "^[1-9][0-9]?$|^100$") { $number_days = $ch }

}

Write-Host 'Модифицирую Spotify...'`n

# Мофифицируем файлы 

$patchFiles = "$PWD\chrome_elf.dll", "$PWD\config.ini"
Copy-Item -LiteralPath $patchFiles -Destination "$spotifyDirectory"

$tempDirectory = $PWD
Pop-Location


Start-Sleep -Milliseconds 200
Remove-Item -Recurse -LiteralPath $tempDirectory 

$xpui_spa_patch = "$env:APPDATA\Spotify\Apps\xpui.spa"
$xpui_js_patch = "$env:APPDATA\Spotify\Apps\xpui\xpui.js"

If (Test-Path $xpui_js_patch) {
    Write-Host "Обнаружен Spicetify"`n

    $xpui_js = Get-Content $xpui_js_patch -Raw
        
    If (!($xpui_js -match 'patched by spotx')) {
        $spotx_new = $true
        Copy-Item $xpui_js_patch "$xpui_js_patch.bak"
    }



    # Отключить подкасты
    if ($Podcasts_off) {
        $xpui_js = $xpui_js `
            -replace '"album,playlist,artist,show,station,episode"', '"album,playlist,artist,station"' -replace ',this[.]enableShows=[a-z]', ""
    }
    $xpui_js = $xpui_js `
        <# Removing an empty block #> `
        -replace 'adsEnabled:!0', 'adsEnabled:!1' `
        <# Full screen mode activation and removing "Upgrade to premium" menu, upgrade button #> `
        -replace '(session[,]{1}[a-z]{1}[=]{1}[a-z]{1}[=]{1}[>]{1}[{]{1}var [a-z]{1}[,]{1}[a-z]{1}[,]{1}[a-z]{1}[;]{1}[a-z]{6})(["]{1}free["]{1})', '$1"premium"' `
        -replace '([a-z]{1}[.]{1}toLowerCase[(]{1}[)]{2}[}]{1}[,]{1}[a-z]{1}[=]{1}[a-z]{1}[=]{1}[>]{1}[{]{1}var [a-z]{1}[,]{1}[a-z]{1}[,]{1}[a-z]{1}[;]{1}return)(["]{1}premium["]{1})', '$1"free"' `
        <# Disabling a playlist sponsor #>`
        -replace "allSponsorships", "" `
        <# Show "Made For You" entry point in the left sidebar #>`
        -replace '(Show "Made For You" entry point in the left sidebar.,default:)(!1)', '$1!0' `
        <# Enables the 2021 icons redraw #>`
        -replace '(Enables the 2021 icons redraw which loads a different font asset for rendering icon glyphs.",default:)(!1)', '$1!0' `
        <# Enable Liked Songs section on Artist page #>`
        -replace '(Enable Liked Songs section on Artist page",default:)(!1)', '$1!0' `
        <# Enable block users #>`
        -replace '(Enable block users feature in clientX",default:)(!1)', '$1!0' `
        <# Enables quicksilver in-app messaging modal #>`
        -replace '(Enables quicksilver in-app messaging modal",default:)(!0)', '$1!1' `
        <# With this enabled, clients will check whether tracks have lyrics available #>`
        -replace '(With this enabled, clients will check whether tracks have lyrics available",default:)(!1)', '$1!0' `
        <# Enables new playlist creation flow #>`
        -replace '(Enables new playlist creation flow in Web Player and DesktopX",default:)(!1)', '$1!0'

    Set-Content -Path $xpui_js_patch -Force -Value $xpui_js
    if ($spotx_new) { add-content -Path $xpui_js_patch -Value '// Patched by SpotX' -passthru | Out-Null }
    $contentjs = [System.IO.File]::ReadAllText($xpui_js_patch)
    $contentjs = $contentjs.Trim()
    [System.IO.File]::WriteAllText($xpui_js_patch, $contentjs)
}  


If (Test-Path $xpui_spa_patch) {

    # Делаем резервную копию xpui.spa если он оригинальный

    Add-Type -Assembly 'System.IO.Compression.FileSystem'
    $zip = [System.IO.Compression.ZipFile]::Open($xpui_spa_patch, 'update')
    $entry = $zip.GetEntry('xpui.js')
    $reader = New-Object System.IO.StreamReader($entry.Open())
    $patched_by_spotx = $reader.ReadToEnd()
    $reader.Close()

    If (!($patched_by_spotx -match 'patched by spotx')) {
        $spotx_new = $true 
        $zip.Dispose()    
        Copy-Item $xpui_spa_patch $env:APPDATA\Spotify\Apps\xpui.bak
    }
    else { $zip.Dispose() }
    
    Add-Type -Assembly 'System.IO.Compression.FileSystem'
    $zip = [System.IO.Compression.ZipFile]::Open($xpui_spa_patch, 'update')
    
    # xpui.js
    $entry_xpui = $zip.GetEntry('xpui.js')

    # Extract xpui.js from zip to memory
    $reader = New-Object System.IO.StreamReader($entry_xpui.Open())
    $xpuiContents = $reader.ReadToEnd()
    $reader.Close()



    # Отключить подкасты
    if ($podcasts_off) {
        $xpuiContents = $xpuiContents `
            -replace '"album,playlist,artist,show,station,episode"', '"album,playlist,artist,station"' -replace ',this[.]enableShows=[a-z]', ""
    }
    $xpuiContents = $xpuiContents `
        <# Removing an empty block #> `
        -replace 'adsEnabled:!0', 'adsEnabled:!1' `
        <# Full screen mode activation and removing "Upgrade to premium" menu, upgrade button #> `
        -replace '(session[,]{1}[a-z]{1}[=]{1}[a-z]{1}[=]{1}[>]{1}[{]{1}var [a-z]{1}[,]{1}[a-z]{1}[,]{1}[a-z]{1}[;]{1}[a-z]{6})(["]{1}free["]{1})', '$1"premium"' `
        -replace '([a-z]{1}[.]{1}toLowerCase[(]{1}[)]{2}[}]{1}[,]{1}[a-z]{1}[=]{1}[a-z]{1}[=]{1}[>]{1}[{]{1}var [a-z]{1}[,]{1}[a-z]{1}[,]{1}[a-z]{1}[;]{1}return)(["]{1}premium["]{1})', '$1"free"' `
        <# Disabling a playlist sponsor #>`
        -replace "allSponsorships", "" `
        <# Disable Logging #>`
        -replace "sp://logging/v3/\w+", "" `
        <# Show "Made For You" entry point in the left sidebar #>`
        -replace '(Show "Made For You" entry point in the left sidebar.,default:)(!1)', '$1!0' `
        <# Enables the 2021 icons redraw #>`
        -replace '(Enables the 2021 icons redraw which loads a different font asset for rendering icon glyphs.",default:)(!1)', '$1!0' `
        <# Enable Liked Songs section on Artist page #>`
        -replace '(Enable Liked Songs section on Artist page",default:)(!1)', '$1!0' `
        <# Enable block users #>`
        -replace '(Enable block users feature in clientX",default:)(!1)', '$1!0' `
        <# Enables quicksilver in-app messaging modal #>`
        -replace '(Enables quicksilver in-app messaging modal",default:)(!0)', '$1!1' `
        <# With this enabled, clients will check whether tracks have lyrics available #>`
        -replace '(With this enabled, clients will check whether tracks have lyrics available",default:)(!1)', '$1!0' `
        <# Enables new playlist creation flow #>`
        -replace '(Enables new playlist creation flow in Web Player and DesktopX",default:)(!1)', '$1!0' `
        <# Enable Enhance Playlist UI and functionality #>`
        -replace '(Enable Enhance Playlist UI and functionality",default:)(!1)', '$1!0'


        

    $writer = New-Object System.IO.StreamWriter($entry_xpui.Open())
    $writer.BaseStream.SetLength(0)
    $writer.Write($xpuiContents)
    if ($spotx_new) { $writer.Write([System.Environment]::NewLine + '// Patched by SpotX') }
    $writer.Close()


    # vendor~xpui.js
    $entry_vendor_xpui = $zip.GetEntry('vendor~xpui.js')

    # Extract vendor~xpui.js from zip to memory
    $reader = New-Object System.IO.StreamReader($entry_vendor_xpui.Open())
    $xpuiContents_vendor = $reader.ReadToEnd()
    $reader.Close()
    
    $xpuiContents_vendor = $xpuiContents_vendor `
        <# Disable Sentry" #> -replace "prototype\.bindClient=function\(\w+\)\{", '${0}return;'
    
    # Rewrite it to the zip
    $writer = New-Object System.IO.StreamWriter($entry_vendor_xpui.Open())
    $writer.BaseStream.SetLength(0)
    $writer.Write($xpuiContents_vendor)
    $writer.Close()




    $zip.Entries | Where-Object FullName -like '*.js' | ForEach-Object {
        $readerjs = New-Object System.IO.StreamReader($_.Open())
        $xpuiContents_js = $readerjs.ReadToEnd()
        $readerjs.Close()

        # NEW JS
        $xpuiContents_js = $xpuiContents_js `
            -replace "[/][/][#] sourceMappingURL=.*[.]map", "" `
            -replace "\r?\n(?!\(1|\d)", ""

        $writer = New-Object System.IO.StreamWriter($_.Open())
        $writer.BaseStream.SetLength(0)
        $writer.Write($xpuiContents_js)
        $writer.Close()
    }



    # *.Css
    $zip.Entries | Where-Object FullName -like '*.css' | ForEach-Object {
        $readercss = New-Object System.IO.StreamReader($_.Open())
        $xpuiContents_css = $readercss.ReadToEnd()
        $readercss.Close()

        # Remove RTL
        $xpuiContents_css = $xpuiContents_css `
            -replace "}\[dir=ltr\]\s?", "} " `
            -replace "html\[dir=ltr\]", "html" `
            -replace ",\s?\[dir=rtl\].+?(\{.+?\})", '$1' `
            -replace "[\w\-\.]+\[dir=rtl\].+?\{.+?\}", "" `
            -replace "\}\[lang=ar\].+?\{.+?\}", "}" `
            -replace "\}\[dir=rtl\].+?\{.+?\}", "}" `
            -replace "\}html\[dir=rtl\].+?\{.+?\}", "}" `
            -replace "\}html\[lang=ar\].+?\{.+?\}", "}" `
            -replace "\[lang=ar\].+?\{.+?\}", "" `
            -replace "html\[dir=rtl\].+?\{.+?\}", "" `
            -replace "html\[lang=ar\].+?\{.+?\}", "" `
            -replace "\[dir=rtl\].+?\{.+?\}", "" `
            -replace "[/]\*([^*]|[\r\n]|(\*([^/]|[\r\n])))*\*[/]", "" `
            -replace "[/][/]#\s.*", "" `
            -replace "\r?\n(?!\(1|\d)", ""
    
        $writer = New-Object System.IO.StreamWriter($_.Open())
        $writer.BaseStream.SetLength(0)
        $writer.Write($xpuiContents_css)
        $writer.Close()

    }
    

    # *.Html
    $zip.Entries | Where-Object FullName -like '*.html' | ForEach-Object {
        $readerhtml = New-Object System.IO.StreamReader($_.Open())
        $xpuiContents_html = $readerhtml.ReadToEnd()
        $readerhtml.Close()

        # файлы html, сокращение размера
        $xpuiContents_html = $xpuiContents_html `
            -replace '<li><a href="#6eef7">zlib<\/a><\/li>\n(.|\n)*<\/p><!-- END CONTAINER DEPS LICENSES -->(<\/div>)', '$2' `
            -replace "	", "" -replace "  ", "" -replace "(?m)(^\s*\r?\n)", "" -replace "\r?\n(?!\(1|\d)", ""
    
        $writer = New-Object System.IO.StreamWriter($_.Open())
        $writer.BaseStream.SetLength(0)
        $writer.Write($xpuiContents_html)
        $writer.Close()
    }


    # Доперевод файла ru.json
    $zip.Entries | Where-Object FullName -like '*ru.json' | ForEach-Object {
        $readerjson = New-Object System.IO.StreamReader($_.Open())
        $xpuiContents_json = $readerjson.ReadToEnd()
        $readerjson.Close()

    
        $xpuiContents_json = $xpuiContents_json `
            -replace '"one": "Enhanced with [{]0[}] recommended song."', '"one": "Добавлен {0} рекомендованный трек."' `
            -replace '"few": "Enhanced with [{]0[}] recommended songs."', '"few": "Добавлено {0} рекомендованных трека."' `
            -replace '"many": "Enhanced with [{]0[}] recommended songs."', '"many": "Добавлено {0} рекомендованных треков."' `
            -replace '"other": "Enhanced with [{]0[}] recommended songs."', '"other": "Добавлено {0} рекомендованных трека."' `
            -replace '"To Enhance this playlist, you.ll need to go online."', '"Чтобы улучшить этот плейлист, вам нужно подключиться к интернету."' `
            -replace '"Song Radio"', '"Радио по треку"' `
            -replace '"Album Radio"', '"Радио по альбому"' `
            -replace '"Artist Radio"', '"Радио по исполнителю"' `
            -replace '"Radio",', '"Радио",' `
            -replace '"Your Location"', '"Ваше местоположение"' `
            -replace '"We couldn.t find concerts in your location."', '"Мы не смогли найти концерты в вашем регионе."' `
            -replace '"We couldn.t find concerts in [{]0[}]."', '"Мы не смогли найти концерты в {0}."' `
            -replace '"Download error"', '"Ошибка загрузки"' `
            -replace '"Layout"', '"Расположение"' `
            -replace '"Confirm your age"', '"Подтвердите свой возраст"' `
            -replace '"Get Spotify Premium"', '"Получите Premium Spotify"' `
            -replace '"Subscribe"', '"Подписаться"' `
            -replace '"%price%\/month after. Terms and conditions apply. One month free not available for users who have already tried Premium."', '"%price%/месяц спустя. Принять условия. Один месяц бесплатно, недоступно для пользователей, которые уже попробовали Premium."' `
            -replace '"Enjoy ad-free music listening, offline listening, and more. Cancel anytime."', '"Наслаждайтесь прослушиванием музыки без рекламы, прослушиванием в офлайн режиме и многим другим. Отменить можно в любое время."' `
            -replace '"Sort by"', '"Сортировка по"' `
            -replace '"Filter by"', '"Фильтр по"' `
            -replace '"Lyrics provided by [{]0[}]"', '"Тексты песен предоставлены {0}"' `
            -replace '"Edit details"', '"Редактировать детали"' `
            -replace '"Decrease navigation bar width"', '"Уменьшить ширину панели навигации"' `
            -replace '"Increase navigation bar width"', '"Увеличить ширину панели навигации"' `
            -replace '"Add to another playlist"', '"Добавить в другой плейлист"' `
            -replace '"Offline storage location"', '"Оффлайн-хранилище"' `
            -replace '"Change location"', '"Изменить расположение"' `
            -replace '"Line breaks aren.t supported in the description."', '"В описании не поддерживаются разрывы строк."' `
            -replace '"HTML isn.t supported in playlist description."', '"HTML не поддерживается в описании плейлиста."' `
            -replace '"Press save to keep changes you.ve made."', '"Нажмите «Сохранить», чтобы сохранить внесенные изменения."' `
            -replace '"No internet connection found. Changes to description and image will not be saved."', '"Подключение к интернету не найдено. Изменения в описании и изображении не будут сохранены."' `
            -replace '"Image too large. Please select an image below 4MB."', '"Изображение слишком большое. Пожалуйста, выберите изображение размером менее 4 МБ."' `
            -replace '"Image too small. Images must be at least [{]0[}]x[{]1[}]."', '"Изображение слишком маленькое. Изображения должны быть не менее {0}x{1}."' `
            -replace '"Failed to upload image. Please try again."', '"Не удалось загрузить изображение. Пожалуйста, попробуйте снова."' `
            -replace '"Playlist name is required."', '"Имя плейлиста обязательно."' `
            -replace '"Failed to save playlist changes. Please try again."', '"Не удалось сохранить изменения в плейлисте. Пожалуйста, попробуйте снова."' `
            -replace '"Description"', '"Описание"' `
            -replace '"Add an optional description"', '"Добавьте дополнительное описание"' `
            -replace '"Change photo"', '"Сменить изображение"' `
            -replace '"Remove photo"', '"Удалить изображение"' `
            -replace '"Name"', '"Имя"' `
            -replace '"Add a name"', '"Добавить имя"' `
            -replace '"Change speed"', '"Изменение скорости"' `
            -replace '"You need to be at least 19 years old to listen to explicit content marked with"', '"Вам должно быть не менее 19 лет, чтобы слушать непристойный контент, помеченный значком"' `
            -replace '"Continue"', '"Продолжить"' `
            -replace '"Add to this playlist"', '"Добавить в этот плейлист"' `
            -replace '"Retrying in [{]0[}]..."', '"Повторная попытка в {0}..."' `
            -replace '"Couldn.t connect to Spotify."', '"Не удалось подключиться к Spotify."' `
            -replace '"Reconnecting..."', '"Повторное подключение..."' `
            -replace '"No connection"', '"Нет соединения"' `
            -replace '"Character counter"', '"Счетчик символов"' `
            -replace '"Toggle lightsaber hilt. Current is [{]0[}]."', '"Переключить рукоять светового меча. Текущий {0}."' `
            -replace '"Song not available"', '"Песня недоступна"' `
            -replace '"The song you.re trying to listen to is not available in HiFi at this time."', '"Песня, которую вы пытаетесь прослушать, в настоящее время недоступна в HiFi."' `
            -replace '"Current audio quality:"', '"Текущее качество звука:"' `
            -replace '"Network connection"', '"Подключение к сети"' `
            -replace '"Good"', '"Хорошее"' `
            -replace '"Poor"', '"Плохое"' `
            -replace '"Yes"', '"Да"' `
            -replace '"No"', '"Нет"' `
            -replace '"Go to playlist"', '"Перейти к плейлисту"' `

        $writer = New-Object System.IO.StreamWriter($_.Open())
        $writer.BaseStream.SetLength(0)
        $writer.Write($xpuiContents_json)
        $writer.Close()

    }

    # json
    $zip.Entries | Where-Object FullName -like '*.json' | ForEach-Object {
        $readerjson = New-Object System.IO.StreamReader($_.Open())
        $xpuiContents_json = $readerjson.ReadToEnd()
        $readerjson.Close()

    
        $xpuiContents_json = $xpuiContents_json `
            -replace "  ", "" -replace "    ", "" -replace '": ', '":' -replace "\r?\n(?!\(1|\d)", "" 

        $writer = New-Object System.IO.StreamWriter($_.Open())
        $writer.BaseStream.SetLength(0)
        $writer.Write($xpuiContents_json)
        $writer.Close()
            
    }

    $zip.Dispose()   
}


# Если папки по умолчанию Dekstop не существует, то попытаться найти её через реестр.
$ErrorActionPreference = 'SilentlyContinue' 

if (Test-Path "$env:USERPROFILE\Desktop") {  

    $desktop_folder = "$env:USERPROFILE\Desktop"
    
}

$regedit_desktop_folder = Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders\"
$regedit_desktop = $regedit_desktop_folder.'{754AC886-DF64-4CBA-86B5-F7FBF4FBCEF5}'
 
if (!(Test-Path "$env:USERPROFILE\Desktop")) {
    $desktop_folder = $regedit_desktop
    
}

# Испраление бага ярлыка на рабочем столе
$ErrorActionPreference = 'SilentlyContinue' 

If (!(Test-Path $env:USERPROFILE\Desktop\Spotify.lnk)) {
  
    $source = "$env:APPDATA\Spotify\Spotify.exe"
    $target = "$desktop_folder\Spotify.lnk"
    $WorkingDir = "$env:APPDATA\Spotify"
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($target)
    $Shortcut.WorkingDirectory = $WorkingDir
    $Shortcut.TargetPath = $source
    $Shortcut.Save()      
}


# Блокировка обновлений

$ErrorActionPreference = 'SilentlyContinue'

$update_directory = Test-Path -Path $env:LOCALAPPDATA\Spotify
$migrator_bak = Test-Path -Path $env:APPDATA\Spotify\SpotifyMigrator.bak  
$migrator_exe = Test-Path -Path $env:APPDATA\Spotify\SpotifyMigrator.exe
$Check_folder_file = Get-ItemProperty -Path $env:LOCALAPPDATA\Spotify\Update | Select-Object Attributes 
$folder_update_access = Get-Acl $env:LOCALAPPDATA\Spotify\Update



if ($block_update) {

    # Если была установка клиента 
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


        # Удалить папку Update если она есть
        if ($Check_folder_file -match '\bDirectory\b') {  

            # Если у папки Update заблокированы права то разблокировать 
            if ($folder_update_access.AccessToString -match 'Deny') {

        ($ACL = Get-Acl $env:LOCALAPPDATA\Spotify\Update).access | ForEach-Object {
                    $Users = $_.IdentityReference 
                    $ACL.PurgeAccessRules($Users) }
                $ACL | Set-Acl $env:LOCALAPPDATA\Spotify\Update
            }
            Remove-item $env:LOCALAPPDATA\Spotify\Update -Recurse -Force
        } 

        # Создать файл Update если его нет
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
}



# Автоматическая очистка кеша


if ($cache_install) {

    $test_cache_spotify_ps = Test-Path -Path $env:APPDATA\Spotify\cache-spotify.ps1
    $test_spotify_vbs = Test-Path -Path $env:APPDATA\Spotify\Spotify.vbs

    If ($test_cache_spotify_ps) {
        Remove-item $env:APPDATA\Spotify\cache-spotify.ps1 -Recurse -Force
    }
    If ($test_spotify_vbs) {
        Remove-item $env:APPDATA\Spotify\Spotify.vbs -Recurse -Force
    }
    Start-Sleep -Milliseconds 200

    # cache-spotify.ps1
    $webClient.DownloadFile('https://raw.githubusercontent.com/amd64fox/SpotX/main/Cache/cache_spotify_ru.ps1', "$env:APPDATA\Spotify\cache-spotify.ps1")

    # Spotify.vbs
    $webClient.DownloadFile('https://raw.githubusercontent.com/amd64fox/SpotX/main/Cache/Spotify.vbs', "$env:APPDATA\Spotify\Spotify.vbs")


    # Spotify.lnk
    $source2 = "$env:APPDATA\Spotify\Spotify.vbs"
    $target2 = "$desktop_folder\Spotify.lnk"
    $WorkingDir2 = "$env:APPDATA\Spotify"
    $WshShell2 = New-Object -comObject WScript.Shell
    $Shortcut2 = $WshShell2.CreateShortcut($target2)
    $Shortcut2.WorkingDirectory = $WorkingDir2
    $Shortcut2.IconLocation = "$env:APPDATA\Spotify\Spotify.exe"
    $Shortcut2.TargetPath = $source2
    $Shortcut2.Save()


    if ($number_days -match "^[1-9][0-9]?$|^100$") {
        $file_cache_spotify_ps1 = Get-Content $env:APPDATA\Spotify\cache-spotify.ps1 -Raw
        $new_file_cache_spotify_ps1 = $file_cache_spotify_ps1 -replace '-7', - $number_days
        Set-Content -Path $env:APPDATA\Spotify\cache-spotify.ps1 -Force -Value $new_file_cache_spotify_ps1
        $contentcache_spotify_ps1 = [System.IO.File]::ReadAllText("$env:APPDATA\Spotify\cache-spotify.ps1")
        $contentcache_spotify_ps1 = $contentcache_spotify_ps1.Trim()
        [System.IO.File]::WriteAllText("$env:APPDATA\Spotify\cache-spotify.ps1", $contentcache_spotify_ps1)
        Write-Host "Установка завершена"`n -ForegroundColor Green
        exit
    }
}

Write-Host "Установка завершена"`n -ForegroundColor Green
exit
