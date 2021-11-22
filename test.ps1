$wshell = New-Object -ComObject Wscript.Shell
$Output = $wshell.Popup("Скрипт формирования отчета завершен! Хотите вывести его на экран?",0,"Отчет готов",4+32)
if($Output -eq 6){
$Output = $wshell.Popup("Отчет выведен на экран",0,"Отчет готов",0+32)
}
if($Output -eq 7){
$Output = $wshell.Popup("Работа завершена",0,"Отчет готов",0+32)
}
