import struct, sys, re
d = open(sys.argv[1],'rb').read()
h = struct.unpack('>4sIIQQIQQQQQQQQQQQII', d[:128])
auth_sz, aux_sz, desc_off, desc_sz, flags = h[3], h[4], h[14], h[15], h[17]
aux = d[256+auth_sz : 256+auth_sz+aux_sz]
off, end = desc_off, desc_off+desc_sz
TAG = {0:'property',1:'hashtree',2:'hash',3:'kernel_cmdline',4:'chain_partition'}
print("  FLAGS 0x%x" % flags)
while off < end:
    tag, nbf = struct.unpack('>QQ', aux[off:off+16])
    b = aux[off+16:off+16+nbf]
    names = re.findall(rb'[ -~]{3,}', b)
    print("    %-16s nbf=%-6d %s" % (TAG.get(tag,tag), nbf, b" | ".join(names[:4]).decode()))
    off += 16 + ((nbf+7)//8)*8
