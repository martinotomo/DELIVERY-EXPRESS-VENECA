# Build de entrega en Windows (PC de Tomás). Para en el primer fallo:
# licencias -> importar -> pruebas -> exportar el .exe -> comprobar arranque -> .zip.
#
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1
#
# Necesita las plantillas de exportación de Godot 4.7.2 en
# %APPDATA%\Godot\export_templates\4.7.2.stable (Editor -> Administrar plantillas de exportación).
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$Godot = $env:GODOT
if (-not $Godot) {
    $Godot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path $Godot)) { throw "No encuentro Godot en $Godot (se puede dar con `$env:GODOT)" }
$Plantillas = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable\windows_release_x86_64.exe"
if (-not (Test-Path $Plantillas)) { throw "Faltan las plantillas de exportación 4.7.2 ($Plantillas)" }

$Version = (Select-String -Path project.godot -Pattern '^config/version="(.*)"').Matches[0].Groups[1].Value
$Nombre = "DeliveryExpress-$Version-windows"
$Salida = "build\$Nombre"
New-Item -ItemType Directory -Force build | Out-Null

function Paso($texto) { Write-Host "== $texto" -ForegroundColor Yellow }
function Falla($texto) { Write-Host "FALLA: $texto" -ForegroundColor Red; exit 1 }

Paso "1/6 licencias"
python tools\check_entrega.py
if ($LASTEXITCODE -ne 0) { Falla "check_entrega.py" }

Paso "2/6 importar"
& $Godot --headless --path . --import 2>&1 | Out-Null
if (-not (Test-Path localization\pantallas.en.translation)) { Falla "no se importaron las traducciones" }

Paso "3/6 pruebas"
& $Godot --headless --path . -s res://tests/run_tests.gd 2>&1 | Tee-Object -FilePath build\pruebas.log | Select-Object -Last 1
if ($LASTEXITCODE -ne 0) { Falla "pruebas (ver build\pruebas.log)" }

Paso "4/6 exportar"
if (Test-Path $Salida) { Remove-Item -Recurse -Force $Salida }
New-Item -ItemType Directory -Force $Salida | Out-Null
& $Godot --headless --path . --export-release "Windows" "$Salida\DeliveryExpress.exe" 2>&1 | Out-File build\export.log
if (-not (Test-Path "$Salida\DeliveryExpress.exe")) { Falla "no salió el .exe (ver build\export.log)" }

Paso "5/6 comprobar arranque"
# Godot 4.7 ya no deja el ejecutable de consola: se lee el log (CLAUDE.md §4).
$Log = Join-Path (Resolve-Path build) "arranque.log"
if (Test-Path $Log) { Remove-Item $Log }
$Reloj = [Diagnostics.Stopwatch]::StartNew()
$p = Start-Process -FilePath "$Salida\DeliveryExpress.exe" -ArgumentList "--log-file", "`"$Log`"", "--", "--prueba-arranque" -PassThru
if (-not $p.WaitForExit(120000)) { $p.Kill(); Falla "el .exe no cerró en 120 s" }
$Texto = Get-Content $Log -Raw
if ($Texto -notmatch "Delivery Express $Version \(release\)") { Falla "el .exe no arrancó como versión de entrega (ver $Log)" }
if ($Texto -notmatch "trucos=false") { Falla "las teclas de prueba F9/F10 están prendidas" }
if ($Texto -notmatch "prueba-arranque: OK") { Falla "no llegó a la calle (ver $Log)" }
if ($Texto -match "SCRIPT ERROR") { Falla "errores de script (ver $Log)" }
$Linea = ($Texto -split "`n" | Where-Object { $_ -match "prueba-arranque: moto" }) -join ""
Write-Host "   arrancó en $([int]$Reloj.Elapsed.TotalSeconds) s (incluye 7 s de prueba): $Linea"

Paso "6/6 zip"
Copy-Item docs\entrega\LEEME.txt, assets\LICENSES.md, assets\AI_DISCLOSURE.md, assets\fuentes\OFL.txt $Salida
$Zip = "build\$Nombre.zip"
if (Test-Path $Zip) { Remove-Item $Zip }
Compress-Archive -Path $Salida -DestinationPath $Zip
Get-Item $Zip | Select-Object Name, Length
