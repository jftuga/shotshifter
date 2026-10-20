# Supported formats and limitations

[Back to README](../README.md)

## Image processing

ShotShifter finds axis labels with Apple's Vision text recognition, adds a fixed offset to every time, erases the old labels and draws new ones in a matching color and size. PNG output is pixel-identical outside the redrawn labels (unless `--box` is given). JPEG output is re-encoded, so it differs slightly everywhere.

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
