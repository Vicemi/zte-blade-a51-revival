# Respaldo genérico del firmware V1.13

Estas son las **particiones genéricas** del firmware `TEL_MX_ZTE_Blade_A51V1.13`
— las mismas en todos los A51 con esta versión. Sirven para **revivir el
firmware** de otro equipo sin tocar su identidad.

Verifica la integridad con:
```bash
sha256sum -c SHA256SUMS
```

## ⚠️ Privacidad — qué NO está aquí (a propósito)

**Se excluyeron las particiones con datos personales o de calibración**, porque
son **únicas de cada teléfono** y **no debes flashearlas en otro** (le romperías
el IMEI, la calibración de radio o el número de serie):

| Excluida | Contenía |
|---|---|
| `l_fixnv1`, `l_fixnv2` | NV del módem: **IMEI**, banda, calibración RF |
| `l_deltanv`, `l_runtimenv1`, `l_runtimenv2` | NV (deltas / runtime) |
| `prodnv` | NV de producción: **serie, MAC WiFi/BT** |
| `persist`, `ztepersist` | calibración de sensores, persist de ZTE |
| `ztecfg`, `miscdata` | config/datos del equipo |
| `teecfg` | config del TEE (claves del equipo) |
| `uboot_log` | log de arranque (no aporta al revival) |

> Se verificó con una búsqueda del IMEI sobre las 46 particiones incluidas:
> **0 coincidencias**. No hay datos personales en lo que se comparte.

## Descarga / Download

El respaldo V1.13 genérico completo (todas las imágenes, sin datos personales)
está en MediaFire / The full generic V1.13 backup (all images, no personal data):

**[MediaFire — v1.13-generico.zip](https://www.mediafire.com/file/42a9cm8vp5ch9yq/v1.13-generico.zip/file)**

`super.img` pesa ~2.8 GB, por eso el respaldo va fuera del repo git (GitHub no
aloja ficheros tan grandes). En este repo solo quedan este README y el
`SHA256SUMS` para verificar la descarga.

## Para restaurar a stock

Ver [Wiki · Respaldo completo](../../../wiki/5-Respaldo-Completo). Resumen por
fastbootd:
```bash
fastboot flash super super.img
fastboot flash vbmeta_a vbmeta_a.img
fastboot flash vbmeta_b vbmeta_b.img
fastboot flash boot_b  boot_b.img
fastboot erase userdata
```
