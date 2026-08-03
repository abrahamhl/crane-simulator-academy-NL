@echo off
REM Doble clic para ejecutar las dos suites de tests.
REM Resultados en logs\MODULE_TEST_RESULTS.json y logs\SELFTEST_RESULTS.json
cd /d "%~dp0"

set "GODOT=tools\godot\Godot_v4.6.3-stable_win64_console.exe"
set "OUT=%~dp0logs"

if not exist "%GODOT%" (
    echo  ERROR: no encuentro Godot en %~dp0%GODOT%
    pause
    exit /b 1
)

echo.
echo  [1/2] Logica pura: fisica, cinematica, tablas de carga, eslingado,
echo        estabilidad y maquina de guia ^(22 comprobaciones^)...
echo.
"%GODOT%" --headless --path src/simulator --script res://tests/module_tests.gd -- --out="%OUT%"
set "R1=%ERRORLEVEL%"

echo.
echo  [2/2] Escena completa: construye las 7 maquinas en los 5 emplazamientos
echo        y recorre los 21 escenarios ^(94 comprobaciones^)...
echo.
"%GODOT%" --headless --fixed-fps 60 --path src/simulator res://game/session.tscn -- --selftest --out="%OUT%"
set "R2=%ERRORLEVEL%"

echo.
echo  ==========================================================
if "%R1%"=="0" (echo   Logica pura ....... OK) else (echo   Logica pura ....... FALLO)
if "%R2%"=="0" (echo   Escena completa ... OK) else (echo   Escena completa ... FALLO)
echo  ==========================================================
echo   Resultados detallados en la carpeta logs\
echo.
pause
