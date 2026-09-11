#!/bin/bash
# Analiza el uboot_log capturado justo despues del arranque fallido.
#
# Lo que buscamos es UNA linea que diga por que el gestor de arranque no
# entrego el control al kernel. Si pone AVB / verify / hash, el diagnostico
# queda cerrado. Si pone otra cosa, hay algo mas que mirar.
C=/mnt/f/ZTE/port/cazado
L="$C/uboot_log_magisk.img"

[ -e "$L" ] || { echo "  no existe $L"; exit 1; }
echo "=== tamano y cuanto hay escrito de verdad ==="
ls -l "$L" | awk '{print "  "$5" bytes en el fichero"}'
python3 - <<'PY'
p = "/mnt/f/ZTE/port/cazado/uboot_log_magisk.img"
d = open(p, 'rb').read()
nz = sum(1 for b in d if b)
print("  %d bytes no nulos (%.3f%%)" % (nz, 100.0 * nz / len(d)))
PY

echo
echo "=== lineas legibles (las ultimas son las del fallo) ==="
strings -a "$L" | tail -60 | sed 's/^/  /'

echo
echo "=== lineas que apuntan a la causa ==="
strings -a "$L" | grep -aiE "avb|verif|hash|vbmeta|dm-verity|signature|boot_b|slot|ramdisk|kernel|fail|error|invalid|corrupt|reboot|panic" \
  | sort -u | head -40 | sed 's/^/  /'

echo
echo "=== sysdumpdb (panicos de kernel): hay algo? ==="
S="$C/sysdumpdb_magisk.img"
if [ -e "$S" ]; then
    python3 - <<'PY'
import os
p = "/mnt/f/ZTE/port/cazado/sysdumpdb_magisk.img"
d = open(p, 'rb').read()
nz = sum(1 for b in d if b)
print("  %d bytes no nulos de %d" % (nz, len(d)))
print("  -> si es ~0, el kernel NUNCA arranco: muere en el gestor de arranque")
PY
    strings -a "$S" | head -10 | sed 's/^/    /'
fi
