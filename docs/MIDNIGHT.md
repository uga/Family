# Midnight — what Family asks of the client, and what Midnight answers

The first step of the `midnight` branch, and the one everything after it is written from: which
of the things Family calls Midnight **lacks**, which it has and **answers differently**, and
which it has and **throws**. Measured in a running Midnight client, never from pages about Retail.
The thesis of `addons/Family/Capabilities.lua` holds here more than anywhere: the client's symbol
surface is not evidence about the game.

This file lives on the branch and lands with it. At 5.0.0 what it found moves into
`DATASOURCES.md` §2 and `Capabilities.lua`, and this file goes.

## 1. What Family touches, counted 2026-09-18

Counted by `tools/surface.py` from the sources at `2d9780c`, the compiler's bytecode listing for
globals and the source for what the listing cannot see:

| Surface | Count |
|---|---|
| Globals Family reads that Lua does not define | 193 |
| Members of `C_*` namespaces, `Enum` and `TooltipDataProcessor` | 39 |
| Upper-case string literals, asked about as events | 136 |
| Frame templates, with the frame type each is built on | 6 |

The names themselves are in `tools/FamilySurface/Surface.lua`, which is generated and is the
list. It is not copied here, so it cannot drift from a second copy. `tools/surface.py --check`
says whether it is still current. It is to be run after every `git merge main`.

## 2. How Midnight is asked

`tools/FamilySurface`, a throwaway addon, run once on Midnight and once on Mists for comparison.
It records the type of every name, whether every literal registers as an event, whether every
template builds, and the answer or the error of 99 read-only calls. Its README says how to run
it.

## 3. What Midnight answered

**Not yet measured.** Waiting on two files from Alberto: `FamilySurface.lua` saved variables
from a Midnight login and from a Mists login.

When they arrive, this section gets four lists, each name with the Family files that use it:

- **Absent** on Midnight and present on Mists.
- **Present and throws** when called.
- **Present and answers differently** from Mists, in shape rather than in value.
- **Events refused** on Midnight and registered on Mists.

Plus whatever the client did when asked to load an addon with no Midnight interface number.

### Loading an addon without Midnight's interface number: refused, observed 2026-09-19

Alberto: Midnight marks Family Surface as *incompatible* and refuses to load it. Its `.toc`
listed `11509, 20506, 50504` and nothing for Midnight. So on Midnight the out-of-date route
that step 2 of the probe's README relied on does not load the addon, and a probe needs the real
number in its `.toc`. The same holds for Family: until the fourth number is in both `.toc`
files, Midnight does not load Family at all. It does not load it and then fail.
