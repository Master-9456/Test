<# 
Имя: Скрипт для очистки кеша Spotify.

Описание: Скрипт очищает устаревший кеш от прослушанной музыки в Spotify.
Срабатывает каждый раз когда вы полностью закрываете клиент (Если клиент был свернут в трей то скрипт не сработает).

Для папки APPDATA\Spotify\Data действует правило, все файлы кеша которые не использовадись
клиентом больше указанного количества дней будут удалены (По умолчанию равно 23 дней).

#>

$day = 23 # Количество дней после которых кеш считается устаревшим 

# Очищает папку \Data если найдет устаревший кеш
try{
If (!(Test-Path -Path $env:LOCALAPPDATA\Spotify\Data)) {
 "$(Get-Date -uformat ‘%D %T’) Папка Local\Spotify\Data не найдена" | Out-File log.txt -append	
}
$check = Get-ChildItem $env:LOCALAPPDATA\Spotify\Data -File -Recurse | Where-Object lastaccesstime -lt (get-date).AddDays(-$day)
if($check.Length -ge 1){

$count = $check
$sum = $count | Measure-Object -Property Length -sum
if($sum.Sum -ge 1073741824){
$gb = "{0:N2} Gb" -f (($check | Measure-Object Length -s).sum/ 1Gb)
"$(Get-Date -uformat ‘%D %T’) Удалено $gb устаревшего кеша" | Out-File log.txt -append
}
else {
$mb = "{0:N2} Mb" -f (($check | Measure-Object Length -s).sum/ 1Mb)
"$(Get-Date -uformat ‘%D %T’) Удалено $mb устаревшего кеша" | Out-File log.txt -append
}
Get-ChildItem $env:LOCALAPPDATA\Spotify\Data -File -Recurse | Where-Object lastaccesstime -lt (get-date).AddDays(-$day) | Remove-Item
}
if($check.Length -lt 1){
"$(Get-Date -uformat ‘%D %T’) Устаревшего кеша не найдено" | Out-File log.txt -append
}   
}
catch
{
"$(Get-Date -uformat ‘%D %T’) $error[0].Exception" | Out-File log.txt -append
}
exit