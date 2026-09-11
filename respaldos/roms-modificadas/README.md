# ROMs modificadas — artefactos de firma

Aquí están las piezas **firmadas** que hacen que las ROMs modificadas arranquen
en este equipo (ver [Wiki · La clave — Firma AVB](../../../wiki/6-La-Clave-Firma-AVB)).

## Qué hay

| Fichero | Qué es | Para qué |
|---|---|---|
| `vbmeta_system_lineage20.img` | `vbmeta_system` con el hashtree de **AndyYan LineageOS 20 a64 gapps (20251021)**, firmado | instalar **exactamente** esa build de LineageOS 20 |
| `vbmeta_system_gsi.img` | `vbmeta_system` con el hashtree del **TrebleDroid AOSP a64 vanilla (A13)** | instalar ese GSI vanilla |
| `vbmeta_disabled_rb1.img` | `vbmeta` con verificación desactivada + rollback 1 (re-firmado) | **referencia** — NO funcionó (este bootloader ignora el flag); se deja como ejemplo de lo que **no** hacer |
| `product_empty.img` | ext4 vacío de 16 MB | recrear `product`/`system_ext` para que el `fstab` no se cuelgue |
| `boot_b_magisk26_signed.img` | boot de fábrica + **Magisk v26.4**, re-firmado | root |

## Importante

- **Las imágenes de GSI (system) NO están aquí.** Son de sus autores
  (AndyYan / TrebleDroid) y se descargan de su fuente — no se re-alojan. Ver los
  enlaces en la [Wiki · Instalar un GSI](../../../wiki/8-Instalar-un-GSI).
- Los `vbmeta_system_*.img` valen **solo para la build exacta** con la que se
  generaron. Si usas otra build/fecha, **genera el tuyo** con `avbtool`
  (`--include_descriptors_from_image TU_GSI.img`), porque el Root Digest cambia.
- El `boot_b_magisk26_signed.img` es el boot de **la V1.13**. Si tu equipo tiene
  otra versión de boot, parchea y firma **el tuyo**.

## Claves

Las claves de firma (`rsa4096_vbmeta.pem`, `rsa4096_boot.pem`) están en
`../../firma/`. Son las claves de firma (test keys públicas) de AVB de TomKing062; el bootloader
desbloqueado las tolera.
