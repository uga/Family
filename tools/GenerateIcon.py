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
"""

import math
import os
import struct

SIZE = 64          # each side, a power of two as the client requires
SUPERSAMPLE = 4    # drawn this many times larger and averaged down, for smooth edges

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, os.pardir, "addons", "Family_UI", "Textures", "Family.tga")

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

    if x < 1 or y < 1 or x > SIZE - 1 or y > SIZE - 1:
        return EDGE

    return mix(BACKGROUND_TOP, BACKGROUND_BOTTOM, y / float(SIZE))


def render():
    pixels = []
    step = 1.0 / SUPERSAMPLE

    for row in range(SIZE):
        for column in range(SIZE):
            r = g = b = 0
            for sy in range(SUPERSAMPLE):
                for sx in range(SUPERSAMPLE):
                    colour = sample(column + (sx + 0.5) * step, row + (sy + 0.5) * step)
                    r += colour[0]
                    g += colour[1]
                    b += colour[2]

            count = SUPERSAMPLE * SUPERSAMPLE
            # Opaque throughout: the icon is a tile like the game's own, and the frame
            # around it - minimap ring or broker bar - is what gives it its shape.
            pixels.append(struct.pack("<BBBB", b // count, g // count, r // count, 255))

    return b"".join(pixels)


def write_tga(path, body):
    header = struct.pack(
        "<BBBHHBHHHHBB",
        0,       # no identification field
        0,       # no colour map
        2,       # uncompressed true colour
        0, 0, 0,  # colour map specification, unused
        0, 0,    # origin
        SIZE, SIZE,
        32,      # bits per pixel
        0x28,    # eight alpha bits, and the first row is the top one
    )

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(header)
        handle.write(body)


if __name__ == "__main__":
    write_tga(OUT, render())
    print("wrote %s (%d x %d)" % (os.path.normpath(OUT), SIZE, SIZE))
