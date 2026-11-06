"""Losslessly strip fully opaque PNG alpha and validate PNG chunk metadata.

Usage: python3 scripts/normalize-store-png.py OUTPUT_DIRECTORY
This utility touches PNG files directly in that directory and writes rgb.json.
"""

from pathlib import Path
import binascii
import hashlib
import json
import struct
import sys
import zlib


def chunk(kind, data):
    return (struct.pack('>I', len(data)) + kind + data
            + struct.pack('>I', binascii.crc32(kind + data) & 0xffffffff))


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    return a if pa <= pb and pa <= pc else b if pb <= pc else c


def normalize(path):
    original = path.read_bytes()
    assert original[:8] == b'\x89PNG\r\n\x1a\n', (path, 'signature')
    position, auxiliary, compressed = 8, [], []
    while position < len(original):
        length = struct.unpack('>I', original[position:position + 4])[0]
        kind = original[position + 4:position + 8]
        data = original[position + 8:position + 8 + length]
        crc = struct.unpack('>I', original[position + 8 + length:position + 12 + length])[0]
        assert crc == binascii.crc32(kind + data) & 0xffffffff, (path, kind, 'CRC')
        position += length + 12
        if kind == b'IHDR':
            width, height, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', data)
        elif kind == b'IDAT':
            compressed.append(data)
        elif kind == b'sBIT':
            assert all(0 < n <= 8 for n in data), (path, 'sBIT values')
            assert len(data) in (3, 4), (path, 'sBIT channels')
            auxiliary.append((kind, data[:3]))
        elif kind not in (b'IEND', b'tRNS'):
            auxiliary.append((kind, data))
    assert (depth, compression, filtering, interlace) == (8, 0, 0, 0), (path, 'unsupported encoding')
    assert color in (2, 6), (path, 'unsupported color')
    channels = 4 if color == 6 else 3
    stride = width * channels
    decoded = zlib.decompress(b''.join(compressed))
    assert len(decoded) == height * (stride + 1), (path, 'row length')
    previous = bytearray(stride)
    encoded, pixels = bytearray(), hashlib.sha256()
    for y in range(height):
        offset = y * (stride + 1)
        method = decoded[offset]
        row = bytearray(decoded[offset + 1:offset + stride + 1])
        if method == 1:
            for i in range(channels, stride):
                row[i] = (row[i] + row[i - channels]) & 255
        elif method == 2:
            for i in range(stride):
                row[i] = (row[i] + previous[i]) & 255
        elif method == 3:
            for i in range(stride):
                row[i] = (row[i] + ((row[i - channels] if i >= channels else 0) + previous[i]) // 2) & 255
        elif method == 4:
            for i in range(stride):
                row[i] = (row[i] + paeth(row[i - channels] if i >= channels else 0,
                                        previous[i], previous[i - channels] if i >= channels else 0)) & 255
        else:
            assert method == 0, (path, 'filter')
        if color == 6:
            assert min(row[3::4]) == max(row[3::4]) == 255, (path, y, 'nonopaque pixels')
            rgb = bytearray(width * 3)
            rgb[0::3], rgb[1::3], rgb[2::3] = row[0::4], row[1::4], row[2::4]
        else:
            rgb = row
        encoded.append(0)
        encoded.extend(rgb)
        pixels.update(rgb)
        previous = row
    result = (b'\x89PNG\r\n\x1a\n'
              + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
              + b''.join(chunk(kind, data) for kind, data in auxiliary)
              + chunk(b'IDAT', zlib.compress(encoded, 6)) + chunk(b'IEND', b''))
    path.write_bytes(result)
    return {'file': path.name, 'width': width, 'height': height, 'mode': 'RGB',
            'bytes': len(result), 'sha256': hashlib.sha256(result).hexdigest(),
            'rgbPixelsSha256': pixels.hexdigest(), 'alphaWasFullyOpaque': True,
            'crcVerified': True, 'sbitChannels': 3}


if __name__ == '__main__':
    root = Path(sys.argv[1]).resolve()
    result = [normalize(path) for path in sorted(root.glob('*.png'))]
    (root / 'rgb.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'{root}: {len(result)} RGB screenshots, CRC/sBIT validated')
