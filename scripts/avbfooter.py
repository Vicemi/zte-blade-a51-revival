# Muestra el pie AVB (ultimos 64 bytes) de una imagen de particion.
import sys, struct
for p in sys.argv[1:]:
    d = open(p, 'rb').read()
    f = d[-64:]
    print("  %s" % p)
    if f[:4] != b'AVBf':
        print("     SIN pie AVB  (ultimos 16 bytes: %s)" % f[-16:].hex())
        continue
    magic, vmaj, vmin, orig_sz, vb_off, vb_sz = struct.unpack('>4sIIQQQ', f[:36])
    print("     pie AVBf  version %d.%d  imagen_original=%d  vbmeta_off=%d  vbmeta_sz=%d"
          % (vmaj, vmin, orig_sz, vb_off, vb_sz))
    vb = d[vb_off:vb_off+vb_sz]
    print("     vbmeta en el pie: %s" % ("AVB0 OK" if vb[:4] == b'AVB0' else "ROTO %s" % vb[:8].hex()))
