#!/bin/bash
#
# Rescate del bucle de arranque POR BOOT ROM (no por fastboot, que no entra).
#
#   arreglar : borra metadata, cache y userdata. Es lo que 'fastboot -w' dejo a
#              medias (cache dio FAILED y metadata ni se toco). metadata guarda
#              las claves de cifrado y el estado de instantaneas de la ROM
#              ANTERIOR; arrancar otra ROM con eso da bucle.
#
#   volver   : restaura la V1.13 completa desde el volcado verificado.
#
# NO SE TOCA 'misc' A PROPOSITO. En su offset 0x800 vive el bootloader_control
# con las prioridades y banderas de los slots. Borrarlo dejaria los dos slots
# marcados como no arrancables, que es exactamente como quedo brickeado ayer.
set -u

FDL=/mnt/f/ZTE/port/fdl
D=/mnt/f/ZTE/port/dump-v113
SPD=/usr/local/bin/spd_dump
LOG=/mnt/f/ZTE/port/rescate2.log

exec > >(tee "$LOG") 2>&1
modprobe vhci-hcd 2>/dev/null

MODO="${1:-arreglar}"

for f in "$SPD" "$FDL/fdl1-sign.bin" "$FDL/fdl2-sign.bin"; do
    [ -e "$f" ] || { echo "FALTA: $f"; exit 1; }
done

echo "=============================================================="
echo " Rescate por boot ROM - modo: $MODO   ($(date +%T))"
echo "=============================================================="

ARGS=("$SPD" --verbose 1 --wait 300
      keep_charge 1
      fdl "$FDL/fdl1-sign.bin" 0x00005000
      fdl "$FDL/fdl2-sign.bin" 0x9efffe00
      disable_transcode
      partition_list "$D/particiones.xml")

case "$MODO" in
  leer)
      # SOLO LECTURA. Saca el rastro que deja el arranque fallido:
      #   uboot_log  - lo que imprime el bootloader: panel, verity, AVB, y si
      #                llega a entregar el control al kernel
      #   sysdumpdb  - donde Unisoc guarda los panicos de kernel
      #   misc       - el BCB, por si algo esta pidiendo recovery en bucle
      # Con esto se sabe si muere en bootloader, en kernel o en init, en vez
      # de seguir probando a ciegas.
      #   cache      - ahi deja el recovery su last_log / last_kmsg
      #   metadata   - estado de instantaneas y cifrado
      mkdir -p /mnt/f/ZTE/port/cazado
      ARGS+=(blk_size 0x8000
             read_part uboot_log 0 4M   /mnt/f/ZTE/port/cazado/uboot_log.img
             read_part sysdumpdb 0 10M  /mnt/f/ZTE/port/cazado/sysdumpdb.img
             read_part misc      0 1M   /mnt/f/ZTE/port/cazado/misc.img
             read_part cache     0 100M /mnt/f/ZTE/port/cazado/cache.img
             read_part metadata  0 16M  /mnt/f/ZTE/port/cazado/metadata.img)
      ;;
  verity)
      # LA CORRECCION DE VERDAD, deducida del uboot_log.
      #
      # El bootloader carga la vbmeta de fabrica, que tiene FLAGS=0x0 (verity
      # totalmente activo) y encadena vbmeta_system / vbmeta_product /
      # vbmeta_system_ext con los hashes de ZTE. Nuestro system, product y
      # system_ext son de LineageOS y no cuadran con esos hashes, asi que
      # dm-verity rechaza el montaje e init reinicia. Encaja con que sysdumpdb
      # este vacio: no hay panico, no llega ni a montar.
      #
      # Se escribe la MISMA vbmeta de fabrica con el bit de hashtree apagado.
      # Asi la cadena sigue intacta y valida para boot, dtbo, socko, odmko,
      # l_modem y los DSP (que no hemos tocado), pero deja de comprobar los
      # sistemas de ficheros que si cambiamos.
      #
      # TAMANO: 61440 bytes = 0xF000 = 5 bloques EXACTOS de 0x3000.
      # En el intento anterior se mandaron 65536 y el FDL escribio 0xF000 y
      # rechazo el sexto bloque, que iba parcial (4096 B):
      #     load_partition: vbmeta_a, target: 0x10000, written: 0xf000
      # O sea: este FDL solo acepta escrituras en bloques completos. Con
      # multiplo exacto no hay bloque parcial que rechazar. La estructura
      # vbmeta mide 15552 B, asi que cabe de sobra en los 61440.
      #
      # ORDEN: vbmeta_b PRIMERO. Es el slot activo, el que de verdad importa;
      # si algo aborta a mitad, que sea despues de haberlo escrito.
      F=/mnt/f/ZTE/port/fix113
      for f in vbmeta_a_verity_off.img vbmeta_b_verity_off.img; do
          [ -e "$F/$f" ] || { echo "FALTA $F/$f"; exit 1; }
      done
      ARGS+=(blk_size 0x3000
             erase_part metadata
             write_part vbmeta_b "$F/vbmeta_b_verity_off.img"
             write_part vbmeta_a "$F/vbmeta_a_verity_off.img")
      ;;
  leervolver)
      # LEE los logs y RESTAURA, todo en una sola sesion de boot ROM, para no
      # repetir la maniobra de botones dos veces.
      #
      # El orden importa: primero leer (el estado del fallo aun esta en el
      # disco), y solo despues sobrescribir con el respaldo.
      mkdir -p /mnt/f/ZTE/port/cazado
      for f in super.img vbmeta_b.img misc.img; do
          [ -e "$D/$f" ] || { echo "FALTA $D/$f"; exit 1; }
      done
      ARGS+=(blk_size 0x8000
             read_part uboot_log 0 4M   /mnt/f/ZTE/port/cazado/uboot_log.img
             read_part sysdumpdb 0 10M  /mnt/f/ZTE/port/cazado/sysdumpdb.img
             read_part misc      0 1M   /mnt/f/ZTE/port/cazado/misc.img
             read_part cache     0 100M /mnt/f/ZTE/port/cazado/cache.img
             read_part metadata  0 16M  /mnt/f/ZTE/port/cazado/metadata.img
             write_part super    "$D/super.img"
             write_part vbmeta_a "$D/vbmeta_a.img"
             write_part vbmeta_b "$D/vbmeta_b.img"
             write_part misc     "$D/misc.img"
             erase_part metadata
             erase_part cache
             erase_part userdata)
      ;;
  fastboot)
      # Mete el equipo en FASTBOOT sin depender de combinaciones de teclas.
      #
      # POR QUE HACE FALTA
      #   Este FDL rechaza SIEMPRE el ultimo bloque de un write_part. En vbmeta
      #   daba igual (la estructura va al principio), pero super son 2800 MB y
      #   su cola si lleva datos. Desde fastboot no existe esa limitacion.
      #
      # COMO
      #   Escribe 'bootonce-bootloader' en el campo command del BCB, que esta
      #   en el offset 0 de misc. Es el mecanismo estandar de Android para
      #   pedirle al bootloader que arranque en fastboot una sola vez.
      #
      #   El bootloader_control (prioridades de slot, magic BCAB) vive en el
      #   offset 0x800 y se copia TAL CUAL desde el misc real del equipo. Por
      #   eso se parte del volcado y no de un fichero en blanco: borrar eso es
      #   lo que dejo el equipo sin arrancar ayer.
      #
      #   Se mandan 3 bloques (36864 B) sabiendo que el FDL escribira 2
      #   (24576 B). BCB y bootloader_control ocupan los primeros 2080 B.
      F=/mnt/f/ZTE/port/fix113
      [ -e "$F/misc_fastboot.img" ] || { echo "FALTA $F/misc_fastboot.img"; exit 1; }
      ARGS+=(blk_size 0x3000
             write_part misc "$F/misc_fastboot.img")
      ;;
  boot)
      # Repone SOLO el boot de fabrica de la V1.13.
      #
      # Se usa cuando se ha escrito un boot.img que no arranca. El bootloader
      # (u-boot) vive en otra particion y no se toca, asi que el boot ROM sigue
      # accesible aunque el equipo este en bucle.
      #
      # boot_b.img mide 67108864 = 64 MB exactos, y 67108864 / 0x8000 = 2048
      # bloques enteros: no queda bloque parcial.
      [ -e "$D/boot_b.img" ] || { echo "FALTA $D/boot_b.img"; exit 1; }
      ARGS+=(blk_size 0x8000
             write_part boot_b "$D/boot_b.img")
      ;;
  arreglar)
      # blk_size grande: aqui solo se borra, no se escribe.
      ARGS+=(blk_size 0x3000
             erase_part metadata
             erase_part cache
             erase_part userdata)
      ;;
  volver)
      for f in super.img vbmeta_a.img vbmeta_b.img; do
          [ -e "$D/$f" ] || { echo "FALTA $D/$f"; exit 1; }
      done
      # blk_size 0x8000 (32768) porque divide EXACTO todos los tamanos:
      #     super  2936012800 / 32768 = 89600
      #     vbmeta    1048576 / 32768 =    32
      #     misc      1048576 / 32768 =    32
      # Asi no hay bloque parcial al final. (Los cortes que veiamos antes no
      # eran del FDL: eran del lanzador reenganchando el USB cada 250 ms.
      # Con eso corregido, misc escribio sus 0x9000 de 0x9000 completos.)
      #
      # Se repone tambien misc, para dejar el BCB y el bootloader_control como
      # estaban antes de todo esto (le metimos 'bootonce-bootloader').
      [ -e "$D/misc.img" ] || { echo "FALTA $D/misc.img"; exit 1; }
      ARGS+=(blk_size 0x8000
             write_part super       "$D/super.img"
             write_part vbmeta_a    "$D/vbmeta_a.img"
             write_part vbmeta_b    "$D/vbmeta_b.img"
             write_part misc        "$D/misc.img"
             erase_part metadata
             erase_part cache
             erase_part userdata)
      ;;
  deshacer)
      # Vuelve atras TODO el intento de root: boot de fabrica Y vbmeta de
      # fabrica, en una sola sesion de boot ROM. Se usa si tras escribir el
      # vbmeta permisivo el equipo no arranca.
      #
      # 0x8000 divide exacto los tres tamanos:
      #     boot_b  67108864 / 32768 = 2048
      #     vbmeta   1048576 / 32768 =   32
      for f in boot_b.img vbmeta_a.img vbmeta_b.img; do
          [ -e "$D/$f" ] || { echo "FALTA $D/$f"; exit 1; }
      done
      ARGS+=(blk_size 0x8000
             write_part boot_b   "$D/boot_b.img"
             write_part vbmeta_b "$D/vbmeta_b.img"
             write_part vbmeta_a "$D/vbmeta_a.img")
      ;;
  root)
      # Instala el root en UNA sola sesion de boot ROM, sin usar fastboot.
      #
      # POR QUE NO POR FASTBOOT
      #   El fastboot de este u-boot cuelga el USB al escribir una imagen
      #   mas pequena que la particion. Los 61440 B de vbmeta en una
      #   particion de 1 MB lo mataron dos veces (serie ????????????  y
      #   "Write to device failed (no link)"). El boot ROM no tiene ese
      #   problema y es la via que siempre ha funcionado aqui.
      #
      # ORDEN: vbmeta PRIMERO. Si algo aborta a mitad queda vbmeta
      # permisiva + boot de fabrica, que arranca igual. Al reves no.
      #
      # 0x8000 (32768) divide exacto los dos tamanos, asi que no queda
      # bloque parcial que el FDL pueda rechazar:
      #     vbmeta   1048576 / 32768 =   32
      #     boot_b  67108864 / 32768 = 2048
      V=/mnt/f/ZTE/port/fix113/vbmeta_b_full_0x3.img
      B=/mnt/f/ZTE/port/magisk/salida/boot_actual.img
      for f in "$V" "$B"; do
          [ -e "$f" ] || { echo "FALTA $f"; exit 1; }
      done
      ARGS+=(blk_size 0x8000
             write_part vbmeta_b "$V"
             write_part boot_b   "$B")
      ;;
  bootmagisk)
      # Escribe SOLO el boot parcheado con Magisk. La vbmeta permisiva ya
      # esta puesta de la pasada anterior.
      #
      # Por que en dos pasadas: este FDL rechaza el ULTIMO bloque de cada
      # write_part y ademas se muere despues ("unexpected response
      # (0xffffffff)" + timeout), asi que solo cabe una particion por
      # sesion. Escribir vbmeta y boot juntos no funciona.
      #
      # Que se pierda el ultimo bloque de boot_b da igual: ahi solo esta el
      # pie AVB, y con la vbmeta en 0x3 ya no se comprueba. La imagen real
      # ocupa 26492928 B, muy por debajo de los 67076096 que si se escriben.
      B=/mnt/f/ZTE/port/magisk/salida/boot_actual.img
      [ -e "$B" ] || { echo "FALTA $B"; exit 1; }
      ARGS+=(blk_size 0x8000 write_part boot_b "$B")
      ;;
  logboot)
      # Sesion B del experimento: LEE el uboot_log recien escrito por el
      # arranque fallido y DESPUES repone el boot de fabrica.
      #
      # El orden importa: si se escribiera primero, el equipo arrancaria
      # bien y sobrescribiria el log, que es justo lo que nos ha impedido
      # diagnosticar esto durante todo el proyecto.
      #
      # Las LECTURAS no matan al FDL (el volcado de 62 particiones salio
      # entero). Lo que lo mata es escribir en vbmeta.
      mkdir -p /mnt/f/ZTE/port/cazado
      [ -e "$D/boot_b.img" ] || { echo "FALTA $D/boot_b.img"; exit 1; }
      ARGS+=(blk_size 0x8000
             read_part uboot_log 0 4M  /mnt/f/ZTE/port/cazado/uboot_log_magisk.img
             read_part sysdumpdb 0 10M /mnt/f/ZTE/port/cazado/sysdumpdb_magisk.img
             write_part boot_b "$D/boot_b.img")
      ;;
  fixvbmeta)
      # Repone SOLO vbmeta_a y vbmeta_b de fabrica (verity ENCENDIDO),
      # para sacar del cuelgue que provoca un vbmeta con verity apagado.
      # NO borra datos, NO toca super ni boot (el boot con Magisk se queda).
      # Calca el orden y blk_size del modo volver, que si escribe vbmeta bien.
      for f in vbmeta_a.img vbmeta_b.img; do
          [ -e "$D/$f" ] || { echo "FALTA $D/$f"; exit 1; }
      done
      ARGS+=(blk_size 0x8000
             write_part vbmeta_a "$D/vbmeta_a.img"
             write_part vbmeta_b "$D/vbmeta_b.img")
      ;;
  gsifix)
      # LEE el uboot_log (para ver por que el bootloader rechaza el vbmeta
      # del GSI y hace bootloop) y ESCRIBE el vbmeta corregido (verity off,
      # rollback 1, re-firmado) en ambos slots. Todo en una maniobra.
      mkdir -p /mnt/f/ZTE/port/cazado
      V=/mnt/f/ZTE/port/firma/vbmeta_disabled_rb1.img
      [ -e "$V" ] || { echo "FALTA $V"; exit 1; }
      ARGS+=(blk_size 0x8000
             read_part uboot_log 0 4M /mnt/f/ZTE/port/cazado/uboot_log_gsi.img
             write_part vbmeta_a "$V"
             write_part vbmeta_b "$V")
      ;;
  *)
      echo "uso: $0 [logboot|bootmagisk|root|deshacer|leer|verity|arreglar|volver]"; exit 1 ;;
esac

ARGS+=(reset)

echo "MARCA-EMPIEZA"     # el lanzador vigila esta linea para decir 'suelta'

# spd_dump pide confirmacion por teclado antes de escribir o borrar:
#     Answer "yes" to confirm the "write partition" command:
# El proceso se lanza con la ventana oculta y sin stdin, asi que sin esto se
# queda esperando una respuesta que nadie puede darle. 'yes yes' se la da.
#
# REINTENTOS: la cesion del USB por usbipd es inestable y a veces la primera
# conexion muere con LIBUSB_ERROR_TIMEOUT o con 'ver expected'. El equipo se
# queda en boot ROM hasta que se le reinicia, asi que reintentar en el sitio
# es gratis y evita tener que repetir la maniobra de los botones.
RC=1
for intento in 1 2 3; do
    echo "--- intento $intento/3 ---"
    yes yes | "${ARGS[@]}"
    RC=$?
    [ $RC -eq 0 ] && break
    echo "--- intento $intento fallo (codigo $RC), reintentando en 3 s ---"
    sleep 3
done

echo
echo "=============================================================="
[ $RC -eq 0 ] && echo " TERMINADO OK" || echo " termino con codigo $RC"
echo " (si solo fallo el ultimo bloque de super o vbmeta, no importa:"
echo "  esos ultimos 32 KB son relleno, no datos utiles)"
echo "=============================================================="
exit $RC
