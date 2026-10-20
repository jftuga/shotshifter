# Usage reference

[Back to README](../README.md)

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

See also [supported formats and limitations](formats-and-limitations.md).
