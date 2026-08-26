#!/usr/bin/env python3
# Family - an alt manager for World of Warcraft Classic
# Copyright (C) 2026 Alberto Pittaluga
#
# This program is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# See the LICENSE file at the root of this repository.

"""Family's own icon, as a texture the game will load.

Why a generator rather than a file somebody drew: the icon has to exist at two sizes that
are read very differently - twenty pixels on the minimap and sixteen in a broker bar - and
being able to change one number and look at it again is worth more than any single drawing.
It also keeps the icon in the repository as something readable and licensed, rather than as
an opaque blob nobody can edit.

The mark is three linked nodes: two members below, one above, joined. It is a family tree
with the detail taken out, which is the most that survives at sixteen pixels. Gold on dark,
because that is what every other icon in the game's interface is and an icon that ignores
that reads as somebody else's software.

Written by hand rather than with an image library, because the only thing standing between
this and the game is a TGA header, and a dependency for that is a dependency to install on
every machine that ever wants to change the icon.

    python3 tools/GenerateIcon.py

The game wants an uncompressed 32-bit TGA whose sides are powers of two. Anything else
loads as a green square, which is the client's way of saying it could not read the file.

It writes two files from the one drawing:

    addons/Family_UI/Textures/Family.tga   64px, what the client loads
    docs/images/family-logo.png            400px, what CurseForge shows on the project page

The second exists because a project page needs a logo and the client's texture is neither
the right format nor a usable size for one. It is deliberately the *same* mark rather than
a second drawing: the picture on the page a player installs from should be the picture on
the minimap button they end up with. Nothing about the mark, the palette or the geometry
differs between them - only the size and the container.

PNG is written by hand for the same reason the TGA is. zlib is in the standard library, and
a PNG is four chunks and a CRC on top of it, so there is still nothing to install.
"""

import math
import os
import struct
import zlib

UNIT = 64.0        # the drawing's own coordinate space; every size below is a scaling of it
SIZE = 64          # the texture's side, a power of two as the client requires
LOGO_SIZE = 400    # the project page's logo, which has no power-of-two constraint
SUPERSAMPLE = 4    # drawn this many times larger and averaged down, for smooth edges

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, os.pardir, "addons", "Family_UI", "Textures", "Family.tga")
LOGO_OUT = os.path.join(HERE, os.pardir, "docs", "images", "family-logo.png")

# Warm dark, so the mark sits among the game's own icons rather than on top of them.
BACKGROUND_TOP = (0x2a, 0x20, 0x16)
BACKGROUND_BOTTOM = (0x14, 0x0e, 0x09)
EDGE = (0x0a, 0x07, 0x05)

GOLD = (0xff, 0xd7, 0x5c)
GOLD_DEEP = (0xc8, 0x8f, 0x22)

# In units of the finished 64px icon. One node above, two below it.
#
# The proportions are decided by the sixteen-pixel case rather than by this one. Nodes as
# large as they will go and links as thin as they will survive, because at that size a link
# only has to say the nodes are joined - and a dark ring around each node is what stops the
# three of them melting into one gold blob, which is what the first version did.
PARENT = (32.0, 17.5, 10.0)
CHILDREN = [(15.5, 45.5, 8.5), (48.5, 45.5, 8.5)]
LINK_WIDTH = 2.6
RING = 2.0


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def inside_disc(x, y, disc):
    cx, cy, r = disc
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def inside_ring(x, y, disc, width):
    cx, cy, r = disc
    d = math.hypot(x - cx, y - cy)
    return r - width <= d <= r


def inside_segment(x, y, a, b, width):
    """A line with round ends, which is the only kind that joins circles cleanly."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy
    if length == 0:
        return False
    t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / length))
    return math.hypot(x - (ax + dx * t), y - (ay + dy * t)) <= width / 2.0


NODES = [PARENT] + CHILDREN


def sample(x, y):
    """The colour at a point, in the finished icon's own coordinates.

    Painted back to front: background, then the links, then a dark ring around each node,
    then the node itself. The ring goes over the links on purpose - it is the gap that
    makes three nodes read as three when each of them is four pixels across.
    """
    for disc in NODES:
        if inside_disc(x, y, disc):
            # Lighter towards the top, so a flat circle reads as something with a shape.
            lift = max(0.0, (disc[1] - y) / (disc[2] * 2.0))
            return mix(GOLD_DEEP, GOLD, 0.35 + lift)

    for disc in NODES:
        if inside_ring(x, y, (disc[0], disc[1], disc[2] + RING), RING):
            return EDGE

    for child in CHILDREN:
        if inside_segment(x, y, (PARENT[0], PARENT[1]), (child[0], child[1]), LINK_WIDTH):
            return GOLD_DEEP

    if x < 1 or y < 1 or x > UNIT - 1 or y > UNIT - 1:
        return EDGE

    return mix(BACKGROUND_TOP, BACKGROUND_BOTTOM, y / UNIT)


def render(size, supersample):
    """The drawing, at any size, as a flat list of (red, green, blue) tuples.

    The mark is described once in UNIT coordinates and every size is a scaling of it, so
    the 400px logo and the 64px texture are the same picture rather than two that have to
    be kept in step by hand. At size == UNIT the scale is 1.0 and the arithmetic is what it
    always was, which is what keeps the shipped texture byte-for-byte unchanged.
    """
    pixels = []
    step = 1.0 / supersample
    scale = UNIT / size

    for row in range(size):
        for column in range(size):
            r = g = b = 0
            for sy in range(supersample):
                for sx in range(supersample):
                    colour = sample((column + (sx + 0.5) * step) * scale,
                                    (row + (sy + 0.5) * step) * scale)
                    r += colour[0]
                    g += colour[1]
                    b += colour[2]

            count = supersample * supersample
            pixels.append((r // count, g // count, b // count))

    return pixels


def write_tga(path, pixels, size):
    header = struct.pack(
        "<BBBHHBHHHHBB",
        0,       # no identification field
        0,       # no colour map
        2,       # uncompressed true colour
        0, 0, 0,  # colour map specification, unused
        0, 0,    # origin
        size, size,
        32,      # bits per pixel
        0x28,    # eight alpha bits, and the first row is the top one
    )

    # Opaque throughout: the icon is a tile like the game's own, and the frame around it -
    # minimap ring or broker bar - is what gives it its shape. TGA wants blue first.
    body = b"".join(struct.pack("<BBBB", b, g, r, 255) for r, g, b in pixels)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(header)
        handle.write(body)


def chunk(kind, payload):
    """One PNG chunk: length, type, payload, and a CRC over the type and the payload."""
    return (struct.pack(">I", len(payload)) + kind + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff))


def write_png(path, pixels, size):
    """A PNG, written out rather than rendered by a library.

    Truecolour with alpha, eight bits a channel, no interlacing. Every scanline carries a
    leading filter byte and we use 0 - no filtering - because the picture is a few flat
    regions and deflate handles those without help.
    """
    raw = bytearray()
    for row in range(size):
        raw.append(0)
        for r, g, b in pixels[row * size:(row + 1) * size]:
            raw += struct.pack(">BBBB", r, g, b, 255)

    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n")
        handle.write(chunk(b"IHDR", header))
        handle.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        handle.write(chunk(b"IEND", b""))


if __name__ == "__main__":
    write_tga(OUT, render(SIZE, SUPERSAMPLE), SIZE)
    print("wrote %s (%d x %d)" % (os.path.normpath(OUT), SIZE, SIZE))

    # Two samples a pixel rather than four: at 400px one finished pixel is a sixth of a
    # texture pixel, so the edges are already six times smoother than the case the
    # supersampling was chosen for, and four would be sixteen million samples for no
    # visible difference.
    write_png(LOGO_OUT, render(LOGO_SIZE, 2), LOGO_SIZE)
    print("wrote %s (%d x %d)" % (os.path.normpath(LOGO_OUT), LOGO_SIZE, LOGO_SIZE))
