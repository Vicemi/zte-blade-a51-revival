# Copia una particion vbmeta ENTERA y solo le cambia el campo FLAGS.
#
# Por que a tamano completo: el fastboot de este u-boot se cuelga al escribir
# una imagen mas pequena que la particion (la de 61440 B mato el enlace USB dos
# veces). La escritura de boot_b, que ocupaba la particion exacta, fue limpia.
#
# FLAGS esta en el offset 120 de la cabecera AvbVBMetaImageHeader, 4 bytes big
# endian. Todo lo demas se copia byte a byte desde la imagen de fabrica, asi que
# las 12 cadenas (boot, dtbo, socko, odmko, vbmeta_system, ...) quedan intactas.
import struct, sys
origen, destino, flags = sys.argv[1], sys.argv[2], int(sys.argv[3], 0)
d = bytearray(open(origen, 'rb').read())
if bytes(d[:4]) != b'AVB0':
    sys.exit("  %s no empieza por AVB0" % origen)
antes, = struct.unpack('>I', bytes(d[120:124]))
d[120:124] = struct.pack('>I', flags)
open(destino, 'wb').write(bytes(d))
print("  %s -> %s" % (origen, destino))
print("  FLAGS 0x%x -> 0x%x   tamano %d bytes (particion completa)" % (antes, flags, len(d)))
