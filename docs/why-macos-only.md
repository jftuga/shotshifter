# Why macOS only

[Back to README](../README.md)

ShotShifter runs only on macOS because it is built on frameworks that ship with the OS:

- **Vision** for text recognition;
- **Core Text** for drawing labels;
- **ImageIO** for reading and writing images.

This page explains why it hasn't been ported to open-source libraries for Linux or Windows, and what a port would involve.

## Where Apple frameworks are used

About 60% of the code is pure logic: parsing labels, detecting axes, time arithmetic, and the command line. It depends only on Foundation and [swift-argument-parser](https://github.com/apple/swift-argument-parser), both of which run on Linux. The rest calls Apple frameworks in six files:

| File | Apple dependency | What it does |
| --- | --- | --- |
| `TextRecognizer.swift` | Vision `RecognizeTextRequest` | Recognizes text in the whole image, then in overlapping tiles |
| `TextObservation.swift` | Vision `RecognizedText.boundingBox(for:)` | Finds the box of each label inside a line Vision read as one piece |
| `LabelRenderer.swift` | Core Text, AppKit `NSFont`, Core Graphics | Measures the original ink, erases labels, and draws new text |
| `PixelSampler.swift` | Core Graphics (bitmap only) | Samples background and text colors |
| `ImageFile.swift` | ImageIO, UniformTypeIdentifiers | Loads and saves PNG and JPEG, keeping color profile and DPI |
| `BoxMarker.swift` | Core Graphics | Draws the `--box` review outlines |

## What a port would take

| Concern | Open-source replacement | Difficulty |
| --- | --- | --- |
| Image loading and saving | libpng and libjpeg-turbo. The color profile, DPI, and JPEG metadata that ImageIO preserves automatically must be copied by hand. | Low to medium |
| Bitmap access, fills, outlines | A plain RGBA buffer | Low |
| Text layout and glyph measurement | HarfBuzz (shaping, tabular digits) and FreeType (glyph bounds) | Medium |
| Text drawing | FreeType grayscale rendering with hand-written, gamma-correct alpha blending | Medium |
| Text recognition | Tesseract, or PaddleOCR models running on ONNX Runtime or OpenCV | **High** |

Everything except text recognition is routine work.

## Text recognition is the hard part

The recognition pipeline is tuned to how Vision behaves:

- **Merged lines.** Vision often returns neighboring labels such as `18:00 20:00 22:00` as one line. It also gives an exact box for each label inside that line, which ShotShifter uses to erase and redraw each label separately.
- **Tiling.** Vision misses small labels in large screenshots, so ShotShifter recognizes the image again in overlapping tiles. The tile size and overlap were chosen for Vision's behavior.
- **Duplicates.** The whole-image pass and the tile passes overlap. The parsers reconcile the duplicate readings by how Vision's readings agree and disagree.

A different engine fails in different ways, so all three would need retuning. The open-source candidates:

| Engine | Expected result |
| --- | --- |
| Tesseract | Clearly worse. It is trained on document text. Grafana axis labels are small, anti-aliased, and often light on dark. It needs heavy preprocessing and still confuses digits such as `0`/`8` and `1`/`7`. |
| PaddleOCR (PP-OCR models) | The only open-source option in Vision's class. It reports boxes for whole lines, so the box of each label inside a line can only be estimated. Whether it matches Vision on Grafana screenshots is unknown without testing. |
| Vision-language models | Unsuitable. They can invent a plausible timestamp that fits the axis spacing, and their boxes are too loose for erasing and redrawing. |

Two techniques could bring an open-source build up to Vision, or past it:

- enlarging the text before recognition;
- running two engines and keeping the readings that agree.

Both make it slower, and the install becomes much larger.

ShotShifter's axis check limits the damage from a weaker engine. A label whose time doesn't fit the even spacing of its neighbors is left unchanged with a warning, so most recognition errors show up as **missed** labels, not **wrong** ones. A worse engine would still mean more unchanged labels and more warnings.

## Pros and cons of porting

| Aspect | Pros | Cons |
| --- | --- | --- |
| Accuracy | Pinned model versions give identical results on every machine and OS update | Tesseract is worse than Vision; PaddleOCR is unproven on these screenshots and needs retuning |
| Speed | Tiles could be recognized in parallel; Vision crashes on concurrent requests | Vision runs on the Neural Engine; open-source inference on the CPU over many tiles is likely slower |
| Rendering | Could draw in Inter, the font Grafana uses | Matching Core Text's anti-aliasing with FreeType takes care. Inter could also be bundled with Core Text without a port. |
| Image files | Full control over encoding | Color profiles, DPI, and metadata must be handled by hand |
| Platforms | Linux, Windows, Intel Macs, older macOS, containers, CI | None for existing macOS users |
| Distribution | No dependency on a specific macOS version | Grows from a few MB to tens of MB or more, with model files and several C and C++ libraries to build, ship, and keep patched |
| Code | The logic layer ports as is if the port stays in Swift | Text detection post-processing, CTC decoding, and alpha blending, which Apple provides, must be written or pulled in |

## Summary

A port is straightforward except for text recognition. For text recognition, the realistic open-source replacement is of unknown accuracy on this task and much heavier to ship. Until there is a strong need to run ShotShifter outside macOS, accuracy work goes into the Vision-based pipeline instead.

If a port does happen, the plan is to put text recognition behind a protocol and keep Vision on macOS. The open-source engine would be a second backend for other platforms, not a replacement.
