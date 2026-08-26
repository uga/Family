# Screenshots for the manual

[`../MANUAL.md`](../MANUAL.md) embeds these by name. **Adding one is two steps**: put the file
here under the name below, and put a line in the manual where it belongs —

    ![What it shows](images/whatever.png)

This used to say the picture would appear on its own, which was never true: the manual had no
image syntax in it at all, only `*(figure: name.png)*` written out as words. Eight pictures sat
in this folder doing nothing before anybody noticed. Where a picture has not been taken yet the
manual carries a visible line saying so, rather than a broken image or a silence.

They are named for what they show rather than numbered, so adding one later renumbers nothing.

| File | What to capture |
|---|---|
| `broker-tooltip.png` | the minimap button hovered, showing every realm and the totals |
| `summary-overview.png` | Summary on Overview, a family across two realms, with a totals line |
| `talents.png` | Abilities & Talents, a tree with untaken talents greyed |
| `possessions.png` | Possessions, several containers, one bag hovered for its tooltip |
| `professions.png` | Professions, sorted by difficulty, with the colour counts along the top |
| `character-gear.png` | Character / Equipped gear, the paper-doll layout, an item hovered |
| `character-gear-family.png` | the same section on *Whole family*, several rows, one class picture hovered |
| `guild-share.png` | the Guild tab, one guildmate opened, showing their characters' gear |
| `tooltip-item.png` | any item's tooltip in the game with Family's block on it |
| `wide-family.png` | Wide Family with a link open and its consent grid showing |

Full window, at the default size, with the game's own UI scale. A shot taken at some other
scale reads as a different addon.

## Not for the manual: the icon contact sheet

| File | What to capture |
|---|---|
| `icons-era.png` | `/iconsheet` on Classic Era, scrolled through, one shot per screenful |
| `icons-anniversary.png` | the same on the Anniversary client |
| `icons-mists.png` | the same on Mists of Pandaria |

These are evidence rather than illustration: which stock texture paths each client actually
has, which is the one question the code cannot ask for itself (see
[`../HANDOFF.md`](../HANDOFF.md) §3). Nothing in the manual points at them.

**The icons were chosen on 2026-08-25 and these were never taken**, which is a gap rather than
a closed job. What survives is the decision — the tables in `Window.lua`, `Character.lua` and
`Summary.lua` — and not the reason for it, so the next person to doubt a path has to run the
sheet again rather than look at a picture. Worth capturing the next time all three clients are
open, and worth capturing *before* the next path is added rather than after.
