# ShotShifter

Shift the time axis of dashboard screenshots to another time zone.

ShotShifter is a macOS command-line tool for support work. A customer sends a Grafana screenshot whose X-axis is in one time zone; ShotShifter finds the axis labels with Apple's Vision text recognition, adds a fixed offset to every time, erases the old labels and draws the new ones in a matching color and size. Everything else in the image is left alone: a PNG output is pixel-identical outside the redrawn labels (unless `--box` is given), while a JPEG output is re-encoded and so differs slightly everywhere.

It targets Grafana first but does not depend on it: any screenshot whose X-axis uses the supported label formats should work.

## Requirements

- macOS 26 or later on Apple Silicon
- Xcode or the Swift 6.2 (or later) toolchain

## Install

Build the release binary as your own user first:

```
make release
```

Then install it system-wide into `/usr/local/bin`:

```
sudo make install
```

or into your home directory without `sudo`:

```
make install PREFIX=$HOME/.local
```

`make install` never builds anything; it fails with "run 'make release' first" if there is no release binary. Other targets: `make build` (debug build, the default), `make test` and `make clean`.

## Usage

```
shotshifter --shift <offset> [--force] [--strict | --box] <file> [<file> ...]
shotshifter --version
shotshifter --help
```

| Option | Description |
| --- | --- |
| `-s`, `--shift <offset>` | The amount to add to every X-axis time, as `[+\|-]H[:MM]`: hours 0-26, optional minutes 00-59. Zero is not allowed. |
| `-f`, `--force` | Overwrite an output file that already exists. |
| `--strict` | Do not write an output when shifting it produced any warning. The file counts as not written, so the exit status is 1. |
| `-b`, `--box` | Outline every shifted label in green and everything a warning refers to in red. Cannot be used with `--strict`. |
| `-v`, `--version` | Print the version and exit. |
| `-h`, `--help` | Show help. |

The output is written beside each input with `-shifted` before the extension: `graph1.png` becomes `graph1-shifted.png`. An existing output is skipped with a warning unless `-f` is given. Without `--strict`, a file is written even when it has warnings, and only the warnings show that some labels may have been left unchanged; use `--strict` when only outputs without any warning should be produced.

`--box` makes the output a review copy. A green outline marks each axis label that was shifted (or found on an axis and already correct for the shift) and each rewritten time zone label. A red outline marks the label or text that a warning refers to: a label left unchanged, a new label that may overlap its neighbor, or a time zone that was not rewritten. A time label on an axis with no outline was not shifted, usually because it was never read; that failure produces no warning. A green outline means a label was shifted, not that it was read correctly, so still compare outlined values with the original. On crowded axes an outline's sides are left out where they would cover the next label. The outlines are drawn into the output, so run again without `--box` (and with `-f`) for a copy to send on.

Examples:

```
shotshifter -s -5 graph1.png
shotshifter --shift +5:30 *.png
shotshifter -f -s 9 cpu.png memory.jpg
shotshifter -b -s -5 dashboard.png
```

Each written file prints one line:

```
graph1.png -> graph1-shifted.png (14 labels in 2 rows)
```

Warnings and errors are printed to standard error, in yellow and red when it is a terminal.

Run without arguments, `shotshifter` prints the help and exits 0. Otherwise the exit status is 0 when every file was written, 1 when any file failed or was skipped, and 64 for a command-line error.

## Supported label formats

| Format | Example | Shifted by `-5` |
| --- | --- | --- |
| `HH:mm:ss` | `14:00:30` | `09:00:30` |
| `HH:mm` | `14:00` | `09:00` |
| `MM/DD HH:mm` | `10/16 14:00` | `10/16 09:00` |
| `MM/DD, HH:mm` | `10/16, 14:00` | `10/16, 09:00` |
| `MM/DD` | `10/16` | `10/15 19:00` |

Times are 24-hour. Month and day may also be written without zero padding (`3/14 20:00`, as older Grafana versions draw them); a row written that way stays unpadded. A date-only axis gains a time after shifting, because its ticks no longer sit on midnight, unless the shift is a whole number of days.

Every row of labels must be evenly spaced in time and in pixels, which is how Grafana draws axes. Several panels stacked or side by side are handled; each axis is detected separately. A label that breaks the even spacing of its neighbors is treated as misread. Misread labels, labels that do not belong to a recognized axis, and labels that fit an axis but were read together with other text are all left unchanged with a warning.

A time zone label such as `UTC`, `GMT`, `UTC+02:00` or `GMT-5` anywhere in the image is rewritten to match the shifted axis (`UTC` shifted by `-5` becomes `UTC-05:00`). Named zones such as `America/New_York` and abbreviations such as `EST` cannot be rewritten with a fixed offset; they are left unchanged with a warning.

## Limitations

- **Daylight saving time.** The shift is a fixed offset. Any part of a graph on the other side of a daylight saving change from the rest is shifted by the wrong amount.
- **Day-first dates.** `DD/MM` or `DD.MM` axes are not supported. A `DD/MM` axis whose days are all 12 or less parses as `MM/DD` and is shifted wrongly.
- **Other formats.** 12-hour `AM`/`PM` labels, milliseconds, month (`YYYY-MM`) and year (`YYYY`) axes, rotated tick labels, rows that mix formats, and the Y-axis, legend, tooltip and panel titles are not changed.
- **Fonts.** New labels are drawn in the macOS system font, sized to the original ink. They will not exactly match Grafana's Inter font, and fonts whose `/` is much shorter than the system font's make redrawn dates slightly small.
- **Backgrounds.** Labels are erased with their sampled background color, which assumes the flat background Grafana uses behind axis labels.
- **Abbreviation warnings.** Any all-caps word that is also a time zone abbreviation known to macOS (for example `CAT` or `EAT`) produces a time zone warning even if it means something else in the dashboard.
- **Speed.** Text is recognized in overlapping tiles, one after another, because Vision misses many small labels in large screenshots. A tall full-dashboard screenshot can take several seconds.
- **Image types.** Only PNG and JPEG are read and written.
