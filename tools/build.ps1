# Build de entrega en Windows (PC de Tomás, Windows PowerShell 5.1). Para en el primer fallo:
# licencias -> importar -> pruebas -> exportar -> comprobar arranque -> zips.
#
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1 -ProbarSinFirma   (también abre el .exe sin firma)
#
# Salen dos zips (D31), como en tools/build.sh:
# - ...-windows.zip: el .exe exportado con la plantilla (icono del juego, sin firma). Con el Control
#   inteligente de aplicaciones prendido Windows no lo deja abrir, por eso solo se prueba con -ProbarSinFirma.
# - ...-windows-firmado.zip: Godot 4.7.2 oficial (firmado por Prehensile Tales B.V.) renombrado a
#   DeliveryExpress.exe + DeliveryExpress.pck al lado. Es el que se prueba siempre.
#
# Necesita las plantillas de exportación 4.7.2 en %APPDATA%\Godot\export_templates\4.7.2.stable.
param([switch]$ProbarSinFirma)

# Con "Stop", PowerShell 5.1 vuelve error fatal cualquier línea que Godot escriba en stderr (los
# avisos de «ObjectDB instances were leaked» al cerrar), aunque todo haya salido bien. Por eso se
# deja en "Continue" y cada paso mira $LASTEXITCODE o el archivo que tenía que salir.
$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..")

function Paso($texto) { Write-Host "== $texto" -ForegroundColor Yellow }
function Falla($texto) { Write-Host "FALLA: $texto" -ForegroundColor Red; exit 1 }

# Godot: el de consola para correr pruebas y exportar; el normal (firmado) para el zip firmado.
$Carpeta = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
$Godot = $env:GODOT
if (-not $Godot) { $Godot = Join-Path $Carpeta "Godot_v4.7.2-stable_win64_console.exe" }
$GodotFirmado = $env:GODOT_FIRMADO
if (-not $GodotFirmado) { $GodotFirmado = Join-Path (Split-Path $Godot) "Godot_v4.7.2-stable_win64.exe" }
if (-not (Test-Path $Godot)) { Falla "No encuentro Godot en $Godot (se puede dar con `$env:GODOT)" }
if (-not (Test-Path $GodotFirmado)) { Falla "No encuentro $GodotFirmado (se puede dar con `$env:GODOT_FIRMADO)" }
$Plantilla = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable\windows_release_x86_64.exe"
if (-not (Test-Path $Plantilla)) { Falla "Faltan las plantillas de exportación 4.7.2 ($Plantilla)" }

$Version = (Select-String -Path project.godot -Pattern '^config/version="(.*)"').Matches[0].Groups[1].Value
$Nombre = "DeliveryExpress-$Version-windows"
$Salida = "build\$Nombre"
$Firmado = "build\$Nombre-firmado"
New-Item -ItemType Directory -Force build | Out-Null

# Corre Godot y guarda todo lo que diga (stdout y stderr) en un log, sin que stderr detenga nada.
function Godot-A($log, [string[]]$argumentos) {
    $p = Start-Process -FilePath $Godot -ArgumentList ($argumentos -join " ") -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    Get-Content "$log.err" | Add-Content $log
    Remove-Item "$log.err"
    return $p.ExitCode
}

Paso "1/6 licencias"
python tools\check_entrega.py
if ($LASTEXITCODE -ne 0) { Falla "check_entrega.py" }

Paso "2/6 importar"
Godot-A "build\importar.log" @("--headless", "--path", ".", "--import") | Out-Null
if (-not (Test-Path localization\pantallas.en.translation)) { Falla "no se importaron las traducciones (ver build\importar.log)" }

Paso "3/6 pruebas"
$codigo = Godot-A "build\pruebas.log" @("--headless", "--path", ".", "-s", "res://tests/run_tests.gd")
$resumen = Select-String -Path build\pruebas.log -Pattern "comprobaciones:" | Select-Object -Last 1
Write-Host "   $($resumen.Line)"
if ($codigo -ne 0 -or -not $resumen -or $resumen.Line -notmatch " 0 mal") { Falla "pruebas (ver build\pruebas.log)" }

Paso "4/6 exportar"
foreach ($d in @($Salida, $Firmado)) {
    if (Test-Path $d) { Remove-Item -Recurse -Force $d }
    New-Item -ItemType Directory -Force $d | Out-Null
}
Godot-A "build\export.log" @("--headless", "--path", ".", "--export-release", "`"Windows`"", "`"$Salida\DeliveryExpress.exe`"") | Out-Null
if (-not (Test-Path "$Salida\DeliveryExpress.exe")) { Falla "no salió el .exe (ver build\export.log)" }
Godot-A "build\export-pck.log" @("--headless", "--path", ".", "--export-pack", "`"Windows`"", "`"$Firmado\DeliveryExpress.pck`"") | Out-Null
if (-not (Test-Path "$Firmado\DeliveryExpress.pck")) { Falla "no salió el .pck (ver build\export-pck.log)" }
Copy-Item $GodotFirmado "$Firmado\DeliveryExpress.exe"
$Firma = Get-AuthenticodeSignature "$Firmado\DeliveryExpress.exe"
if ($Firma.Status -ne "Valid") { Falla "el Godot oficial no tiene firma válida: $($Firma.Status)" }
Write-Host "   firma: $($Firma.Status), $($Firma.SignerCertificate.Subject)"

Paso "5/6 comprobar arranque"
# Godot 4.7 ya no deja ejecutable de consola al exportar: se lee el log (CLAUDE.md §4).
function Probar($exe, $modo) {
    $log = Join-Path (Resolve-Path build) "arranque-$modo.log"
    if (Test-Path $log) { Remove-Item $log }
    $reloj = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath $exe -ArgumentList "--log-file", "`"$log`"", "--", "--prueba-arranque" -PassThru
    if (-not $p.WaitForExit(120000)) { $p.Kill(); Falla "$exe no cerró en 120 s" }
    if (-not (Test-Path $log)) { Falla "$exe no arrancó (¿lo bloqueó Windows? ver el Visor de eventos, CodeIntegrity)" }
    $texto = Get-Content $log -Raw
    if ($texto -notmatch "Delivery Express $Version \($modo\)") { Falla "$exe no arrancó como versión $modo (ver $log)" }
    if ($texto -notmatch "trucos=false") { Falla "las teclas de prueba F9/F10 están prendidas en $exe" }
    if ($texto -notmatch "prueba-arranque: OK") { Falla "$exe no llegó a la calle (ver $log)" }
    if ($texto -match "SCRIPT ERROR") { Falla "errores de script en $exe (ver $log)" }
    $linea = ($texto -split "`n" | Where-Object { $_ -match "prueba-arranque: binario" }) -join ""
    Write-Host "   $modo en $([int]$reloj.Elapsed.TotalSeconds) s (incluye ~7 s de prueba): $linea"
}
Probar "$Firmado\DeliveryExpress.exe" "entrega"
if ($ProbarSinFirma) { Probar "$Salida\DeliveryExpress.exe" "release" }

Paso "6/6 zips"
foreach ($d in @($Salida, $Firmado)) {
    Copy-Item docs\entrega\LEEME.txt, assets\LICENSES.md, assets\AI_DISCLOSURE.md, assets\fuentes\OFL.txt $d
}
Copy-Item docs\entrega\GODOT_LICENSE.txt, docs\entrega\GODOT_COPYRIGHT.txt $Firmado
Copy-Item assets\ui\icono.ico "$Firmado\DeliveryExpress.ico"
foreach ($d in @($Salida, $Firmado)) {
    $zip = "$d.zip"
    if (Test-Path $zip) { Remove-Item $zip }
    Compress-Archive -Path $d -DestinationPath $zip
    Get-Item $zip | Select-Object Name, Length | Format-Table -HideTableHeaders
}
