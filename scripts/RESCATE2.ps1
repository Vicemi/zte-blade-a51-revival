# RESCATE2.ps1 - saca al ZTE del bucle usando el BOOT ROM (botones de volumen),
# porque el fastboot no llega a arrancar.  EJECUTAR COMO ADMINISTRADOR.
#
#   ...\RESCATE2.ps1 arreglar   <- prueba esto primero (30 segundos)
#   ...\RESCATE2.ps1 volver     <- restaura la V1.13 entera (10-20 min)
#
# Es la misma via por la que se hizo el volcado, asi que sabemos que funciona
# en este equipo. Necesita administrador por el 'bind --force' de usbipd.
param([string]$Modo = "arreglar")

$usbipd = 'C:\Program Files\usbipd-win\usbipd.exe'
$distro = 'Ubuntu-22.04'
$hwid   = '1782:4d00'
$log    = 'F:\ZTE\port\rescate2.log'

function T($t, $c = 'Cyan') {
    Write-Host ("=" * 62) -ForegroundColor $c
    Write-Host " $t" -ForegroundColor $c
    Write-Host ("=" * 62) -ForegroundColor $c
}

T "Rescate por boot ROM - modo: $Modo"

if (-not (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
   ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
    Write-Host "`nNECESITA ADMINISTRADOR. Abre PowerShell como admin y relanzalo.`n" -ForegroundColor Red
    exit 1
}

if ($Modo -eq 'volver') {
    Write-Host "Va a restaurar la V1.13 desde el volcado:" -ForegroundColor Gray
    Write-Host "  super.img (2800 MB) + vbmeta_a + vbmeta_b, y borra datos." -ForegroundColor Gray
    Write-Host "Tarda entre 10 y 20 minutos. No desconectes el cable.`n" -ForegroundColor Gray
}

Remove-Item $log -Force -ErrorAction SilentlyContinue
wsl.exe -d $distro -u root -- modprobe vhci-hcd 2>&1 | Out-Null

Write-Host "[1/3] arrancando spd_dump (espera hasta 300 s)..." -ForegroundColor Gray
$proc = Start-Process -FilePath 'wsl.exe' `
        -ArgumentList @('-d', $distro, '-u', 'root', '--', 'bash', '/mnt/f/ZTE/port/tools/RESCATE2.sh', $Modo) `
        -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 3
if ($proc.HasExited) { Write-Host "spd_dump murio al arrancar" -ForegroundColor Red; exit 1 }
Write-Host "      ok (PID $($proc.Id))" -ForegroundColor Green

Write-Host ""
Write-Host "  ##########################################################" -ForegroundColor Yellow
Write-Host "  #  EN EL MOVIL, AHORA:                                   #" -ForegroundColor Yellow
Write-Host "  #                                                        #" -ForegroundColor Yellow
Write-Host "  #   1. Manten Power ~20 s hasta que se APAGUE del todo   #" -ForegroundColor Yellow
Write-Host "  #      (tiene que dejar de reiniciarse y quedarse quieto)#" -ForegroundColor Yellow
Write-Host "  #   2. Desconecta el USB                                 #" -ForegroundColor Yellow
Write-Host "  #   3. Manten VOL+ y VOL- a la vez, las dos              #" -ForegroundColor Yellow
Write-Host "  #   4. Sin soltarlas, conecta el USB                     #" -ForegroundColor Yellow
Write-Host "  #                                                        #" -ForegroundColor Yellow
Write-Host "  #   La pantalla NO muestra nada en este modo. Es normal. #" -ForegroundColor Yellow
Write-Host "  ##########################################################" -ForegroundColor Yellow
Write-Host ""
Write-Host "[2/3] vigilando el boot ROM..." -ForegroundColor Gray

$limite = (Get-Date).AddMinutes(6)
$bind = $false; $soltar = $false; $tDet = $null

while ((Get-Date) -lt $limite -and -not $proc.HasExited) {
    $dev = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
           Where-Object { $_.InstanceId -match 'VID_1782&PID_4D00' }
    if ($dev -and -not $bind) {
        # bind + attach UNA SOLA VEZ. Antes esto se repetia cada 250 ms mientras
        # el dispositivo estuviera presente, y cada 'attach' reengancha el USB:
        # si caia mientras spd_dump estaba hablando, la transferencia moria con
        # LIBUSB_ERROR_TIMEOUT. Una vez cedido, no se toca mas.
        Write-Host "[+] boot ROM detectado - cediendo el USB a WSL..." -ForegroundColor Green
        & $usbipd bind --hardware-id $hwid --force 2>&1 | Out-Null
        Start-Sleep -Milliseconds 500
        & $usbipd attach --wsl $distro --hardware-id $hwid 2>&1 | Out-Null
        $bind = $true; $tDet = Get-Date
    }

    # Avisar de soltar cuando spd_dump ya esta trabajando de verdad. Se usan dos
    # senales porque la vez pasada la deteccion por texto nunca disparo:
    #   a) el log crece por encima de la cabecera fija
    #   b) o han pasado 40 s desde que el chip aparecio (FDL1+FDL2 ya cargaron)
    if (-not $soltar) {
        $grande = $false
        if (Test-Path $log) { $grande = (Get-Item $log).Length -gt 400 }
        $viejo = $tDet -and ((Get-Date) - $tDet).TotalSeconds -gt 40
        if ($grande -or $viejo) {
            Write-Host ""
            Write-Host "  ##########################################################" -ForegroundColor Green
            Write-Host "  #   >>> YA PUEDES SOLTAR LOS BOTONES <<<                 #" -ForegroundColor Green
            Write-Host "  #   NO desconectes el cable.                             #" -ForegroundColor Green
            Write-Host "  ##########################################################" -ForegroundColor Green
            Write-Host ""
            $soltar = $true
        }
    }
    Start-Sleep -Milliseconds 250
}

Write-Host "[3/3] esperando a que termine..." -ForegroundColor Gray
$ultima = ""
while (-not $proc.HasExited) {
    if (Test-Path $log) {
        # Mostrar la ultima linea con sentido, no solo los KB: si spd_dump se
        # queda pidiendo algo por teclado (nos paso con la confirmacion de
        # escritura), aqui se ve al momento en vez de parecer que trabaja.
        $l = Get-Content $log -Tail 4 -ErrorAction SilentlyContinue |
             Where-Object { $_ -notmatch '^(send|recv):' -and $_.Trim() -ne '' } |
             Select-Object -Last 1
        if ($l) { $ultima = $l.Trim() }
    }
    $txt = if ($ultima.Length -gt 68) { $ultima.Substring(0, 68) } else { $ultima }
    Write-Host ("`r      {0,-72}" -f $txt) -NoNewline -ForegroundColor Gray
    Start-Sleep -Seconds 2
}
Write-Host ""

Write-Host ""
T "RESULTADO"
if (Test-Path $log) {
    Get-Content $log | Where-Object { $_ -notmatch '^(send|recv):' } | Select-Object -Last 30
}
Write-Host ""
if ($Modo -eq 'arreglar') {
    Write-Host "El movil se reinicia solo. Dale 15 minutos con el logo." -ForegroundColor Gray
    Write-Host "Si vuelve al bucle:" -ForegroundColor Yellow
    Write-Host '  powershell -ExecutionPolicy Bypass -File "F:\ZTE\port\tools\RESCATE2.ps1" volver' -ForegroundColor White
} else {
    Write-Host "Deberia arrancar tu V1.13 de siempre (primer arranque algo lento)." -ForegroundColor Gray
}
