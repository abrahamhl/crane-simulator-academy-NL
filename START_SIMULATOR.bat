@echo off
REM Doble clic para abrir el simulador. Arranca en el menu principal.
REM Cualquier argumento extra se pasa tal cual a Godot.
cd /d "%~dp0"

set "GODOT=tools\godot\Godot_v4.6.3-stable_win64_console.exe"

if not exist "%GODOT%" (
    echo.
    echo  ERROR: no encuentro Godot en:
    echo    %~dp0%GODOT%
    echo.
    pause
    exit /b 1
)

echo.
echo  ==============================================================
echo   GELDERLAND OPERATOR ACADEMY - Simulador de gruas y elevacion
echo  ==============================================================
echo.
echo   AYUDA FORMATIVA UNICAMENTE. El rendimiento en el simulador no
echo   es una certificacion legal y no sustituye a TCVT, VCA ni a
echo   ningun curso acreditado. Las tablas de carga son envolventes
echo   de practica, NO datos de fabricante de ninguna maquina real.
echo.
echo  --------------------------------------------------------------
echo   LOS MANDOS SON IGUALES EN TODAS LAS MAQUINAS
echo  --------------------------------------------------------------
echo     W / S     Alcance fuera / dentro
echo               ^(puente adelante-atras, carro de pluma, telescopar^)
echo     A / D     Izquierda / derecha  ^(carro transversal o GIRO^)
echo     R / F     IZAR / BAJAR el gancho      ^<-- igual siempre
echo     T / G     Subir / bajar la pluma      ^(maquinas con pluma^)
echo     Q / E     Avance por carril           ^(grua ferroviaria^)
echo     SHIFT     Modo lento / fino ^(mantener pulsado^)
echo     ESPACIO   PARADA TOTAL
echo     O         Desplegar / recoger estabilizadores
echo     1 2 3 4   Comprobaciones previas ^(sin ellas no arranca^)
echo     H         Tabla de cargas y plan de izado
echo     B         Llamar al senalista
echo     X         Soltar los mandos
echo     RETROCESO Reiniciar la maquina
echo.
echo   A PIE:  WASD moverse - SHIFT correr - ESPACIO saltar
echo           RATON mirar  - E coger los mandos
echo.
echo   SIEMPRE: TAB camara - C primera persona - M mapa
echo            F1 ayuda   - L idioma          - ESC pausa
echo  --------------------------------------------------------------
echo.
echo   Todo esto tambien esta dentro del juego: menu Controles,
echo   tecla F1 en cualquier momento, y en la pausa ^(ESC^).
echo.
echo   Cierra la ventana del simulador para volver aqui.
echo.

"%GODOT%" --path src/simulator %*

echo.
echo  Simulador cerrado.
pause
