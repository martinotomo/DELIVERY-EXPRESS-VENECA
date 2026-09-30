# Build de entrega en Windows (PC de Tomás, Windows PowerShell 5.1). Para en el primer fallo:
# licencias -> importar -> pruebas -> exportar el .exe -> comprobar arranque -> .zip.
#
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1 -SinProbar   (no abre el .exe)
#
# El .exe no va firmado (D31): con el Control inteligente de aplicaciones de Windows 11 prendido,
# Windows no lo deja abrir y el paso 5 falla; con -SinProbar se salta y Tomás lo prueba a mano.
#
# Necesita las plantillas de exportación 4.7.2 en %APPDATA%\Godot\export_templates\4.7.2.stable.
param([switch]$SinProbar)

# Con "Stop", PowerShell 5.1 vuelve error fatal cualquier línea que Godot escriba en stderr (los
# avisos de «ObjectDB instances were leaked» al cerrar), aunque todo haya salido bien. Por eso se
# deja en "Continue" y cada paso mira el código de salida o el archivo que tenía que salir.
$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..")

function Paso($texto) { Write-Host "== $texto" -ForegroundColor Yellow }
function Falla($texto) { Write-Host "FALLA: $texto" -ForegroundColor Red; exit 1 }

$Godot = $env:GODOT
if (-not $Godot) {
    $Godot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path $Godot)) { Falla "No encuentro Godot en $Godot (se puede dar con `$env:GODOT)" }
$Plantilla = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable\windows_release_x86_64.exe"
if (-not (Test-Path $Plantilla)) { Falla "Faltan las plantillas de exportación 4.7.2 ($Plantilla)" }

$Version = (Select-String -Path project.godot -Pattern '^config/version="(.*)"').Matches[0].Groups[1].Value
$Nombre = "DeliveryExpress-$Version-windows"
$Salida = "build\$Nombre"
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
if (Test-Path $Salida) { Remove-Item -Recurse -Force $Salida }
New-Item -ItemType Directory -Force $Salida | Out-Null
Godot-A "build\export.log" @("--headless", "--path", ".", "--export-release", "`"Windows`"", "`"$Salida\DeliveryExpress.exe`"") | Out-Null
if (-not (Test-Path "$Salida\DeliveryExpress.exe")) { Falla "no salió el .exe (ver build\export.log)" }

Paso "5/6 comprobar arranque"
if ($SinProbar) {
    Write-Host "   saltado (-SinProbar)"
} else {
    # Godot 4.7 ya no deja ejecutable de consola al exportar: se lee el log (CLAUDE.md §4).
    $Log = Join-Path (Resolve-Path build) "arranque.log"
    if (Test-Path $Log) { Remove-Item $Log }
    $Reloj = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath "$Salida\DeliveryExpress.exe" -ArgumentList "--log-file", "`"$Log`"", "--", "--prueba-arranque" -PassThru
    if (-not $p) { Falla "Windows no dejó abrir el .exe (¿Control inteligente de aplicaciones?). Usar -SinProbar" }
    if (-not $p.WaitForExit(120000)) { $p.Kill(); Falla "el .exe no cerró en 120 s" }
    if (-not (Test-Path $Log)) { Falla "el .exe no arrancó (¿lo bloqueó Windows? Visor de eventos, CodeIntegrity). Usar -SinProbar" }
    $Texto = Get-Content $Log -Raw
    if ($Texto -notmatch "Delivery Express $Version \(release\)") { Falla "el .exe no arrancó como versión de entrega (ver $Log)" }
    if ($Texto -notmatch "trucos=false") { Falla "las teclas de prueba F9/F10 están prendidas" }
    if ($Texto -notmatch "prueba-arranque: OK") { Falla "no llegó a la calle (ver $Log)" }
    if ($Texto -match "SCRIPT ERROR") { Falla "errores de script (ver $Log)" }
    $Linea = ($Texto -split "`n" | Where-Object { $_ -match "prueba-arranque: binario" }) -join ""
    Write-Host "   arrancó en $([int]$Reloj.Elapsed.TotalSeconds) s (incluye ~7 s de prueba): $Linea"
}

Paso "6/6 zip"
Copy-Item docs\entrega\LEEME.txt, assets\LICENSES.md, assets\AI_DISCLOSURE.md, assets\fuentes\OFL.txt, `
    docs\entrega\GODOT_LICENSE.txt, docs\entrega\GODOT_COPYRIGHT.txt $Salida
$Zip = "$Salida.zip"
if (Test-Path $Zip) { Remove-Item $Zip }
Compress-Archive -Path $Salida -DestinationPath $Zip
Get-Item $Zip | Select-Object Name, Length | Format-Table -HideTableHeaders
