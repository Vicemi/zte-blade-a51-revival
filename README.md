# ZTE Blade A51 (P963F60) — LineageOS 20 / GSI + Root

### 🌐 Language / Idioma
- 🇬🇧 [**English**](#english) (below)
- 🇪🇸 [**Español**](#español) (más abajo)

---

## English

Install guide to put **LineageOS 20 (Android 13) with Google Play and root** on a
ZTE Blade A51 (Unisoc SC9863A, `P963F60`).

📖 **The full story, the reason behind each step, every error and every finding
are in the [Wiki](../../wiki).** This README is just the quick guide.

> ⚠️ This modifies critical partitions. You can soft-brick the device. Everything
> is recoverable with the backups, but **do it at your own risk**. Back up
> **before** you start.

---

## Requirements

- ZTE Blade A51 `P963F60` with an **unlocked bootloader**
  ([how](../../wiki/4-Desbloqueo-del-Bootloader) · thanks to TomKing062).
- **platform-tools** (adb + fastboot) on the PC.
- An **`a64` (arm32_binder64) GSI**. Recommended:
  **AndyYan LineageOS 20 a64 gapps** (`a64_bgN`) →
  [SourceForge](https://sourceforge.net/projects/andyyan-gsi/files/lineage-20-td/).
- From this repo: `respaldos/roms-modificadas/product_empty.img` and, if you use
  **exactly** that build, `vbmeta_system_lineage20.img`. For any other build,
  generate its `vbmeta_system` (see below).
- Your **V1.13 backup** of `vbmeta_a.img` / `vbmeta_b.img`. Download the full
  generic V1.13 backup here:
  **[MediaFire — v1.13-generico.zip](https://www.mediafire.com/file/42a9cm8vp5ch9yq/v1.13-generico.zip/file)**
  (no personal data — see [Backup](../../wiki/5-Respaldo-Completo)).

## Step 0 — (once) generate your GSI's `vbmeta_system`

Only if you are NOT using the exact build already signed here. With `avbtool` and
the key `firma/rsa4096_vbmeta.pem`:

```bash
avbtool make_vbmeta_image \
  --include_descriptors_from_image YOUR_GSI.img \
  --rollback_index 1 --padding_size 1048576 \
  --algorithm SHA256_RSA4096 --key firma/rsa4096_vbmeta.pem \
  --output vbmeta_system_gsi.img
```

## Step 1 — enter fastbootd

```bash
adb reboot fastboot
fastboot getvar is-userspace      # must say: yes
```
(If it won't boot: power off, enter recovery with **VOL- and Power**, choose
**"Enter fastboot"**. Reference video to reach recovery:
https://www.youtube.com/watch?v=uvh23sqrP30 — you only need to enter recovery and
pick "Enter fastboot"; the wipe cache/reset shown there is **not** needed.)

## Step 2 — flash

```bash
# make room in super
fastboot delete-logical-partition product_b
fastboot delete-logical-partition system_ext_b     # only for big GSIs (~2GB)

# the GSI
fastboot flash system YOUR_GSI.img

# verification: make verity ACCEPT the GSI
fastboot flash vbmeta_system_a vbmeta_system_gsi.img
fastboot flash vbmeta_system_b vbmeta_system_gsi.img
fastboot flash vbmeta_a vbmeta_a.img               # from your V1.13 backup
fastboot flash vbmeta_b vbmeta_b.img

# recreate empty product and system_ext (for the fstab)
fastboot create-logical-partition product_b 16777216
fastboot flash product_b product_empty.img
fastboot create-logical-partition system_ext_b 16777216
fastboot flash system_ext_b product_empty.img

# wipe and boot
fastboot erase metadata
fastboot erase userdata
fastboot reboot
```

## Step 3 — first boot

**It can take over 5 minutes** seemingly stuck on the ZTE logo. **That's normal**
(it formats `/data`, first Android 13 boot). Wait. Then complete the LineageOS
setup wizard on screen (language, WiFi, Google account for Play Store).

## Root (optional, with Magisk)

See [Wiki · Root with Magisk](../../wiki/7-Root-con-Magisk). Summary: patch the
stock boot with Magisk v26.4, re-sign it with `firma/rsa4096_boot.pem`, then
`fastboot flash boot_b`. Root survives reflashing the GSI.

## If something goes wrong — back to stock

```bash
# via fastbootd:
fastboot flash super super.img          # from your V1.13 backup
fastboot flash vbmeta_a vbmeta_a.img
fastboot flash vbmeta_b vbmeta_b.img
fastboot flash boot_b  boot_b.img
fastboot erase userdata
```
Or, if it won't reach fastboot, via **boot ROM**: `scripts/RESCATE2.ps1 volver`.
Details in [Wiki · Full backup](../../wiki/5-Respaldo-Completo).

---

## Repo contents

- `respaldos/v1.13-generico/` — V1.13 firmware backup metadata (README +
  SHA256SUMS). The image files are hosted as a **Release / external mirror**
  (they contain **no personal data**: no IMEI, MAC or serial).
- `respaldos/roms-modificadas/` — the signed `vbmeta_system` files,
  `product_empty`, and the Magisk boot.
- `firma/` — `avbtool` and the (public test) signing keys, from TomKing062.
- `scripts/` — rescue and analysis tools.
- The [**Wiki**](../../wiki) — the full story, the findings, and all the errors.

Credits: TomKing062, TrebleDroid, AndyYan, phhusson, topjohnwu (Magisk),
ilyakurdyukov (spd_dump), LineageOS. Full list in
[Wiki · Credits](../../wiki/11-Creditos).

---
---

## Español

[⬆ English](#english)

Guía de instalación para poner **LineageOS 20 (Android 13) con Google Play y
root** en un ZTE Blade A51 (Unisoc SC9863A, `P963F60`).

📖 **La historia completa, el porqué de cada paso, todos los errores y los
hallazgos están en la [Wiki](../../wiki).** Este README es solo la guía rápida.

> ⚠️ Esto modifica particiones críticas. Puedes dejar el equipo inservible
> temporalmente. Todo es recuperable con los respaldos, pero **es bajo tu propio
> riesgo**. Respalda **antes** de empezar.

## Requisitos

- ZTE Blade A51 `P963F60` con **bootloader desbloqueado**
  ([cómo](../../wiki/4-Desbloqueo-del-Bootloader) · trabajo de TomKing062).
- **platform-tools** (adb + fastboot) en el PC.
- Un **GSI `a64` (arm32_binder64)**. Recomendado:
  **AndyYan LineageOS 20 a64 gapps** (`a64_bgN`) →
  [SourceForge](https://sourceforge.net/projects/andyyan-gsi/files/lineage-20-td/).
- De este repo: `respaldos/roms-modificadas/product_empty.img` y, si usas
  **exactamente** esa build, `vbmeta_system_lineage20.img`. Si usas otra build,
  genera su `vbmeta_system` (ver abajo).
- Tu **respaldo V1.13** de `vbmeta_a.img` / `vbmeta_b.img`. Descarga el respaldo
  V1.13 genérico completo aquí:
  **[MediaFire — v1.13-generico.zip](https://www.mediafire.com/file/42a9cm8vp5ch9yq/v1.13-generico.zip/file)**
  (sin datos personales — ver [Respaldo](../../wiki/5-Respaldo-Completo)).

## Paso 0 — (una vez) generar el `vbmeta_system` de tu GSI

Solo si NO usas la build exacta que ya viene firmada. Con `avbtool` y la clave
`firma/rsa4096_vbmeta.pem`:

```bash
avbtool make_vbmeta_image \
  --include_descriptors_from_image TU_GSI.img \
  --rollback_index 1 --padding_size 1048576 \
  --algorithm SHA256_RSA4096 --key firma/rsa4096_vbmeta.pem \
  --output vbmeta_system_gsi.img
```

## Paso 1 — entrar a fastbootd

```bash
adb reboot fastboot
fastboot getvar is-userspace      # debe decir: yes
```
(Si no arranca: apaga, entra a recovery con **VOL- y Power**, elige **"Enter
fastboot"**. Video de referencia para llegar a recovery:
https://www.youtube.com/watch?v=uvh23sqrP30 — solo necesitas entrar a recovery y
elegir "Enter fastboot"; el wipe cache/reset del video **no** hace falta.)

## Paso 2 — flashear

```bash
# hacer sitio en super
fastboot delete-logical-partition product_b
fastboot delete-logical-partition system_ext_b     # solo si el GSI es grande (~2GB)

# el GSI
fastboot flash system TU_GSI.img

# la verificacion: que verity ACEPTE el GSI
fastboot flash vbmeta_system_a vbmeta_system_gsi.img
fastboot flash vbmeta_system_b vbmeta_system_gsi.img
fastboot flash vbmeta_a vbmeta_a.img               # de tu respaldo V1.13
fastboot flash vbmeta_b vbmeta_b.img

# recrear product y system_ext vacios (para el fstab)
fastboot create-logical-partition product_b 16777216
fastboot flash product_b product_empty.img
fastboot create-logical-partition system_ext_b 16777216
fastboot flash system_ext_b product_empty.img

# datos limpios y arrancar
fastboot erase metadata
fastboot erase userdata
fastboot reboot
```

## Paso 3 — primer arranque

**Puede tardar más de 5 minutos** colgado aparentemente en el logo de ZTE. **Es
normal** (formatea `/data`, primer arranque de Android 13). Espera. Luego
completa el asistente de LineageOS en pantalla (idioma, WiFi, cuenta de Google
para Play Store).

## Root (opcional, con Magisk)

Ver [Wiki · Root con Magisk](../../wiki/7-Root-con-Magisk). Resumen: parchear el
boot de fábrica con Magisk v26.4, re-firmarlo con `firma/rsa4096_boot.pem`, y
`fastboot flash boot_b`. El root sobrevive a reflashear el GSI.

## Si algo sale mal — volver a stock

```bash
# por fastbootd:
fastboot flash super super.img          # de tu respaldo V1.13
fastboot flash vbmeta_a vbmeta_a.img
fastboot flash vbmeta_b vbmeta_b.img
fastboot flash boot_b  boot_b.img
fastboot erase userdata
```
O, si no arranca ni a fastboot, por **boot ROM**: `scripts/RESCATE2.ps1 volver`.
Detalle en [Wiki · Respaldo completo](../../wiki/5-Respaldo-Completo).

## Contenido del repo

- `respaldos/v1.13-generico/` — metadatos del respaldo V1.13 (README +
  SHA256SUMS). Las imágenes van como **Release / espejo externo** (**sin datos
  personales**: sin IMEI, MAC ni serie).
- `respaldos/roms-modificadas/` — los `vbmeta_system` firmados, `product_empty`
  y el boot con Magisk.
- `firma/` — `avbtool` y las claves de firma (test keys públicas) de TomKing062.
- `scripts/` — herramientas de rescate y análisis.
- La [**Wiki**](../../wiki) — la historia completa, los hallazgos y todos los errores.

Créditos: TomKing062, TrebleDroid, AndyYan, phhusson, topjohnwu (Magisk),
ilyakurdyukov (spd_dump), LineageOS. Detalle en
[Wiki · Créditos](../../wiki/11-Creditos).
