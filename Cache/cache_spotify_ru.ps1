<# 
Имя: Скрипт для очистки кеша Spotify.

Описание: Скрипт очищает устаревший кеш от прослушанной музыки в Spotify.
Срабатывает каждый раз когда вы полностью закрываете клиент (Если клиент был свернут в трей то скрипт не сработает).

Для папки APPDATA\Spotify\Data действует правило, все файлы кеша которые не использовадись
клиентом больше указанного количества дней будут удалены (По умолчанию равно 7 дней).

#>

$day = 7 # Количество дней после которых кеш считается устаревшим 

# Очищает папку \Data если найдет устаревший кеш
If (Test-Path -Path $env:LOCALAPPDATA\Spotify\Data) {
    Get-ChildItem $env:LOCALAPPDATA\Spotify\Data -File -Recurse | Where-Object lastaccesstime -lt (get-date).AddDays(-$day) | Remove-Item 
}

exit