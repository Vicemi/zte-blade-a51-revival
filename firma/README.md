# Firma AVB — claves y herramienta

Con esto se firman/certifican las imágenes para que la verificación del
bootloader las **acepte** (ver [Wiki · La clave — Firma AVB](../../wiki/6-La-Clave-Firma-AVB)).

| Fichero | Qué es |
|---|---|
| `avbtool.py` | la herramienta de AVB del AOSP (`external/avb`) |
| `rsa4096_vbmeta.pem` | clave para firmar `vbmeta` / `vbmeta_system` |
| `rsa4096_boot.pem` | clave para firmar el `boot` |

> Son **test keys de AVB** publicadas por **TomKing062** en
> `vendor_sprd_proprietories-source_packimage/sign_image/config-unisoc`. En
> formato son "private keys", pero **están disponibles públicamente y no son
> secretas** — cualquiera las tiene. No dan ninguna propiedad ni seguridad del
> equipo; solo hacen que la firma sea **válida en forma** para que AVB, en un
> bootloader **desbloqueado**, la **acepte**. Por eso funcionan solo en equipos
> desbloqueados.

## Ejemplos

Inspeccionar una imagen:
```bash
python avbtool.py info_image --image boot_b.img
```

`vbmeta_system` para un GSI:
```bash
python avbtool.py make_vbmeta_image \
  --include_descriptors_from_image TU_GSI.img \
  --rollback_index 1 --padding_size 1048576 \
  --algorithm SHA256_RSA4096 --key rsa4096_vbmeta.pem \
  --output vbmeta_system_gsi.img
```

Re-firmar un boot parcheado con Magisk:
```bash
python avbtool.py add_hash_footer \
  --image boot-magisk.img \
  --partition_name boot --partition_size 67108864 \
  --key rsa4096_boot.pem --algorithm SHA256_RSA4096 \
  --rollback_index 1 \
  --prop com.android.build.boot.fingerprint:<FINGERPRINT> \
  --prop com.android.build.boot.os_version:11 \
  --salt <SALT>
```
El `<FINGERPRINT>` y el `<SALT>` salen de `info_image` sobre tu boot de fábrica.
