# Original DOS clock and location table

Decoded from the supplied original executables:

- floppy `DUNEPRG.EXE`, SHA-256 `32439602abe95e0ff778653ad58052bfed56a73e103b92f079455daa2ee886e7`
- CD `DNCDPRG.EXE`, SHA-256 `5f30aeb84d67cf2e053a83c09c2890f010f2e25ee877ebec58ea15c5b30cfff9`

## Tick conversion

The executable programs PIT channel 0 with divisor `$1745` (`0x1745`). The
timer IRQ handler then decrements a word counter and, when it becomes
negative, reloads it from `$2EE0` and increments the 16-bit game-time word.
The relevant handler sequence is present in the post-driver memory dump at
`CS1:1EF70`:

```text
FF 0E DB 46       dec  word [46DB]
79 0E             jns  no_game_time_tick
A1 6E 14          mov  ax,[146E]
A3 DB 46          mov  [46DB],ax
FF 06 02 00       inc  word [0002]
```

The timer setup at `CS1:E8A8` loads `AX=$1745` before writing PIT channel 0.
The reload word observed at `DS=1F4B:146E` is `$2EE0` (`12000`). Since the
handler decrements first and tests for a negative result, one game-time tick
is `$2EE1 = 12001` PIT interrupts.

Using the PC PIT frequency $1{,}193{,}182$ Hz:

$$
f_{\mathrm{IRQ}} = \frac{1{,}193{,}182}{0x1745}
                 = 200.299143864\ \mathrm{Hz}
$$

$$
t_{\mathrm{game\ tick}} = \frac{0x2EE1}{f_{\mathrm{IRQ}}}
                          = 59.915383403\ \mathrm{s}
$$

The 16-bit game-time word is interpreted directly by the original code:

- hour of day: `gameTime & 0x000F` (16 game-time ticks per day);
- sunlight day: `(gameTime + 3) >> 4`;
- the `+3` is not a timing approximation—it is the literal instruction
  sequence used by the original `GetSunlightDay` routine at `CS1:1AD1`.

The Swift implementation keeps the raw 16-bit tick/hour representation and
uses the decoded `59.915383403` seconds per tick. Its four light labels are a
presentation grouping of the 16 original hours; they do not replace the raw
clock.

## Location-table spice density

Both executables contain the same 70 records:

- floppy table file offset: `$EFF0`;
- CD table file offset: `$F7B0`;
- record stride: `$1C` (28 bytes);
- spice-density byte: record offset `$12`.

The exact byte values, in original location-record order (indices `0...69`),
are:

```text
0, 0, 120, 100, 125, 200, 180, 45, 140, 0,
120, 60, 84, 45, 140, 99, 160, 180, 160, 210,
0, 200, 170, 240, 200, 240, 180, 160, 100, 250,
0, 150, 32, 130, 120, 180, 180, 210, 0, 120,
250, 180, 120, 200, 150, 110, 60, 180, 150, 160,
170, 210, 195, 240, 200, 210, 50, 0, 230, 200,
170, 200, 140, 170, 140, 0, 170, 240, 140, 240
```

The table was independently scanned in both binaries using the adjacent
`first_name`/`last_name` bytes and the 70-record stride; the offsets differ
only because the CD executable has a larger preceding image. No values were
copied from a savegame or inferred from the map artwork.
