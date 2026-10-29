# Pakistan Sign Language (PSL) Translator — Full Alphabet Version

A Flutter app + Python training pipeline for **PSL fingerspelling**:
recognise the 37 Urdu-letter PSL alphabet signs from the camera,
build words letter by letter, and practise the alphabet in Learn mode.

Built for Ijaz Muhammad (BSCS, AI / Computer Vision, Flutter + Python).
All code here is original and written to be explainable in an interview.

## What the app does

Three tabs, one shared on-device model:

- **Camera** — live camera preview, the current stable letter (Urdu
  glyph + Roman name + model confidence), spoken aloud when it
  changes. A letter is only accepted after several consistent frames
  with confidence ≥ 0.6, so the display does not flicker.
- **Fingerspelling** — build words letter by letter: sign a letter,
  wait until it is stable, tap **Add letter**. Space, backspace,
  clear and **Speak word** complete the flow. Adding a letter is a
  manual tap on purpose — automatic capture would insert letters on
  every small hand movement.
- **Learn** — the full 37-letter alphabet list (Urdu glyph + Roman
  name). Tap a letter to practise it: the app checks the camera
  prediction against the target and counts matches.

## Honest status — read this first

**A real model is now trained and in the app.** The numbers below
are the measured held-out test result — not training accuracy, not
a rounded-up claim:

1. **Dataset downloaded and prepared (2026-10-28).** The Mendeley
   PSL dataset is in place under `python/data/psl_images/` — 1,509
   real images across all 37 classes, verified by
   `prepare_dataset.py` (exit code 0). See "Dataset" for the full
   facts.
2. **Real training run completed 2026-10-28** (`train_psl.py`,
   MobileNetV2 transfer learning, 15 head epochs + 10 fine-tuning
   epochs, stratified split train 1,055 / val 227 / test 227).
   **Held-out test accuracy: 226/227 = 99.56%.** The saved
   `test_report.txt` shows "accuracy 1.00" because sklearn rounds
   to two decimals — the true figure is 226 correct out of 227,
   not 100%. Per class: 35 of 37 letters perfect; `ray` recall
   0.83 (5/6 — one ray sign misclassified as zaad) and `zaad`
   precision 0.86 (that same ray sample was its one false
   positive). Full report: `python/output/test_report.txt`;
   model: `python/output/model.tflite` (2,561,488 bytes, also
   copied to `flutter_app/assets/` with `labels.txt`, and the
   `assets:` block in `pubspec.yaml` is now enabled).
   **Caveat, stated plainly:** with ~40 images per class the test
   set holds only ~6 images per letter, so 99.56% is a noisy
   number — one more or fewer error moves it by ~0.44 points.
   The dataset is also a single source with limited signers and
   backgrounds, so real-world accuracy on a phone, in new
   lighting, with new signers, will be lower. Treat 99.56% as
   "the model learned this dataset", not "the model works for
   everyone".
3. **No on-device testing has happened yet** — there is no Flutter
   SDK on the machine this was built on, so the app code was
   hand-checked but never compiled or run on a phone.
   `flutter pub get && flutter run` on the user's machine is
   still an unverified step. The TFLite file itself was verified
   here: it loads, takes 224x224x3 float input, outputs 37
   floats, and correctly classified three real dataset samples
   (tay, alif, meem) — a file-integrity check only, not an
   accuracy claim.
4. If the model fails to load on a phone, the app falls back to
   a **clearly-labelled demo** (amber banner, simulated gestures
   only). The demo is never presented as recognition, and
   fingerspelling / Learn practice refuse to run on it.

What the app does NOT do yet, even with a trained alphabet model:
full PSL sentences. Real PSL uses movement over time, both hands and
facial expression, and a vocabulary far beyond 37 letters. The
alphabet model covers fingerspelling — one static hand shape per
letter — which is a real, useful part of PSL, not the whole language.

## The 37-letter alphabet

One class per letter, in this order (folder slug = class name):

| # | Slug | Urdu | Roman | # | Slug | Urdu | Roman |
|---|------|------|-------|---|------|------|-------|
| 1 | alif | ا | Alif | 20 | saad | ص | Saad |
| 2 | bay | ب | Bay | 21 | zaad | ض | Zaad |
| 3 | pay | پ | Pay | 22 | toa | ط | Toa |
| 4 | tay | ت | Tay | 23 | zoa | ظ | Zoa |
| 5 | tey | ٹ | Tey | 24 | ain | ع | Ain |
| 6 | say | ث | Say | 25 | ghain | غ | Ghain |
| 7 | jeem | ج | Jeem | 26 | fay | ف | Fay |
| 8 | chay | چ | Chay | 27 | qaaf | ق | Qaaf |
| 9 | hay | ح | Hay | 28 | kaaf | ک | Kaaf |
| 10 | khay | خ | Khay | 29 | gaaf | گ | Gaaf |
| 11 | daal | د | Daal | 30 | laam | ل | Laam |
| 12 | ddaal | ڈ | Ddaal | 31 | meem | م | Meem |
| 13 | zaal | ذ | Zaal | 32 | noon | ن | Noon |
| 14 | ray | ر | Ray | 33 | wao | و | Wao |
| 15 | rray | ڑ | Rray | 34 | gol_hay | ہ | Gol Hay |
| 16 | zay | ز | Zay | 35 | hamza | ء | Hamza |
| 17 | zhay | ژ | Zhay | 36 | ye | ی | Ye |
| 18 | seen | س | Seen | 37 | bari_ye | ے | Bari Ye |
| 19 | sheen | ش | Sheen | | | | |

Why 37 and not 39: the published alphabet datasets below use a
37-letter set (do-chashmi he, ھ, is not a separate class there).
The same 37 slugs, in the same order, live in three places that must
stay in sync: `python/psl_alphabet.py`,
`flutter_app/lib/models/psl_alphabet.dart`, and the `labels.txt`
written by the training script. The app's classifier refuses to run
if `labels.txt` disagrees with its alphabet, rather than silently
mislabeling signs.

## Dataset — downloaded and prepared (2026-10-28)

**Source:** Mendeley Data, "dataset" — PSL hand-configuration
images, DOI 10.17632/y9svrbh27n.1, licence CC BY 4.0.
The downloaded ZIP (1.05 GB, SHA-256 verified) was extracted to
`python/data/psl_images_raw/`; its nested inner file
`PSL/PSL DATA SET.zip` was deliberately NOT extracted. The original
ZIP was left untouched.

**What is actually in place** (`python/data/psl_images/<slug>/`,
copies, not symlinks, so the training folder is self-contained):

- **1,509 PNG images across all 37 classes** — every image passed a
  PNG magic-byte check.
- Per-class counts: **40 images for 33 classes, 50 for tay, tey
  and say, and 39 for alif** (alif is one short of 40 — counted, not
  hidden). No class is missing or empty.
- `prepare_dataset.py --data-dir data/psl_images` exits 0 and
  reports "All 37 classes present." Its only warning is that 34
  classes have fewer than 50 images — with ~40 images per class the
  stratified 70/15/15 split in `train_psl.py` leaves only ~6 test
  images per class, so test accuracy will be noisy. That is a
  property of this dataset, not a reason to invent more data.
- The training folder is git-ignored (`python/.gitignore` lists
  `data/`), so the images are not committed to the repo.

**Folder mapping — matched by Urdu glyph, not by Roman name.**
The dataset's Roman names differ from this project's slugs
(e.g. "Aliph", "Chhoti yeh", "Djay", "Vao", "Toay'n"), so each
folder was mapped on the Urdu glyph in its name (invisible format
characters in two folder names were ignored). Zero folders were
unmatched and nothing was guessed. The pairs that only the glyph
can separate came out right: "Daal  د" → daal vs "Daal ڈ" →
ddaal; "hey ح" → hay vs "Hay ہ" → gol_hay; "Tay ت" → tay vs
"Tey ٹ" → tey vs "Thay ث" → say. Full table: Aliph→alif,
Bay→bay, Pay→pay, Tay→tay, Tey→tey, Thay→say, Jeem→jeem,
Chay→chay, hey→hay, Khay→khay, Daal (د)→daal, Daal (ڈ)→ddaal,
Dhaal→zaal, Ray→ray, aRay→rray, Zay→zay, Djay→zhay,
Seen→seen, Sheen→sheen, Suaad→saad, Dhuaad→zaad, Toay'n→toa,
Zoay'n→zoa, Ain→ain, Ghain→ghain, Fay→fay, Quaaf→qaaf,
Kaaf→kaaf, Gaaf→gaaf, Laam→laam, Meem→meem, Noon→noon,
Vao→wao, Hay (ہ)→gol_hay, Hamza→hamza, Chhoti yeh→ye,
Bari yeh→bari_ye.

**Not yet verified:** whether each image really shows the letter
its folder claims — the counts and file formats were verified, but
the images themselves have not been visually audited class by
class. Spot-check a few images per class before trusting a trained
model.

Other published PSL datasets, NOT downloaded (possible future
supplements): Kaggle "pakistan-sign-language-dataset" (37 alphabets
+ 12 words) and Kaggle "UAlpha40" (~22,280 images).

## Step 1 — Check the dataset

```bash
cd python
python prepare_dataset.py --data-dir data/psl_images
```

This prints a per-class count table, flags classes with few images,
lists missing/empty classes, and reports unrecognised folders. If the
folder is missing or empty, it says so plainly and exits with code 2
— that is the expected state before a download, not a code error.

## Step 2 — Train (MobileNetV2 transfer learning, 224x224)

```bash
cd python
pip install -r requirements.txt
python train_psl.py --data-dir data/psl_images --output-dir output
```

What it does: stratified ~70/15/15 train/val/test split, MobileNetV2
(ImageNet weights) with a frozen base + new head, then fine-tuning
of the top 30 layers at a low learning rate, with augmentation
(rotation, shift, zoom, horizontal flip) and balanced class weights.
It prints the **held-out test classification report and confusion
matrix** — that printout is the project's real result — and writes:

```
output/model.tflite      # dynamic-range quantized model (float I/O)
output/labels.txt        # one slug per line, in model output order
output/test_report.txt   # the same report + confusion matrix, saved
output/history.json      # training curves
```

Rules: training refuses to run unless all 37 classes are present,
unless you pass `--allow-partial` (which trains a smaller model that
covers only the classes present — labels.txt then lists only those).
The app supports the default dynamic-range export; the optional
`--full-integer` export uses uint8 I/O and needs extra handling in
the Flutter classifier before it can be used.

Tuning knobs: `--epochs`, `--fine-tune-epochs` (0 to skip),
`--unfreeze-layers`, `--batch-size`. See
`python train_psl.py --help`.

## Step 3 — Put the model in the app and run it

**Done 2026-10-28:** `model.tflite` + `labels.txt` are already in
`flutter_app/assets/` (md5-verified copies of `python/output/`)
and the `assets:` block in `flutter_app/pubspec.yaml` is enabled.
Remaining step — run the app:

```bash
cd flutter_app
flutter pub get
flutter run
```

The app tries to load the model on startup. If it loads, all three
tabs run on real recognition; if not, the Camera tab shows the demo
fallback with its amber banner. The demo fallback is the old
rule-based 5-gesture code (`lib/services/gesture_classifier.dart`,
`lib/services/hand_tracking_service.dart`) — kept only for UI
testing, never as a recognition path.

Camera notes: the classifier converts Android YUV420 frames (or iOS
BGRA frames) to RGB, centre-crops to a square, resizes to 224x224,
and scales pixels to [-1, 1] — exactly the MobileNetV2 preprocessing
used in training. If colours look wrong on a device, the U/V plane
order in `psl_classifier.dart` is the first thing to check. Speech
uses the Roman letter names (TTS is en-US); Urdu speech output is
future work, as are Learn-mode reference images
(`flutter_app/assets/learn/<slug>.jpg`, copied from the training
dataset — none are shipped, and no handshape is guessed in their
place).

## Architecture

```
Phone camera
  → PslCameraService (camera + throttle + stability filter)
  → PslClassifierService (TFLite model.tflite + labels.txt)
  → Camera tab: stable letter → big Urdu text + speech
  → Fingerspell tab: stable letters → word builder
  → Learn tab: alphabet list → per-letter camera practice
  → (no model) → DemoScreen: simulated gestures, amber banner

Dataset (python/data/psl_images/<slug>/*.jpg)
  → prepare_dataset.py (counts, missing classes)
  → train_psl.py (MobileNetV2 → model.tflite + labels.txt)
```

The old landmark pipeline (`collect_landmarks.py`,
`train_classifier.py`, `export_tflite.py`,
`generate_synthetic_demo.py`) is a legacy demo path for a
landmark-based classifier. It is NOT the PSL alphabet path, and its
synthetic demo data is NOT PSL data — never train the alphabet
model on it, and never quote its demo accuracy for real signs.

## File list

```
README.md
flutter_app/
  pubspec.yaml                      # + tflite_flutter, image; assets enabled (model trained 2026-10-28)
  assets/model.tflite               # trained model (2,561,488 bytes)
  assets/labels.txt                 # 37 slugs, verified against psl_alphabet.py + Dart alphabet
  assets/README.md                  # where the model files came from
  lib/main.dart                     # HomeScreen: loads model once, 3 tabs
  lib/models/psl_alphabet.dart      # the 37 letters (must match labels.txt)
  lib/models/hand_landmark.dart     # (demo fallback only)
  lib/services/psl_classifier.dart  # TFLite classifier, main path
  lib/services/psl_camera_service.dart  # camera + stability filter
  lib/services/gesture_classifier.dart # (demo fallback only)
  lib/services/hand_tracking_service.dart  # (demo fallback only)
  lib/services/speech_service.dart  # flutter_tts wrapper
  lib/screens/camera_screen.dart    # Camera tab (model) / DemoScreen (fallback)
  lib/screens/demo_screen.dart      # clearly-labelled demo fallback
  lib/screens/fingerspell_screen.dart  # word builder
  lib/screens/learn_screen.dart     # alphabet list + practice
  lib/widgets/gesture_display.dart  # (demo fallback only)
python/
  psl_alphabet.py                   # the 37 slugs (single source of truth)
  prepare_dataset.py                # per-class counts, missing classes
  train_psl.py                      # MobileNetV2 → TFLite + report
  requirements.txt
  collect_landmarks.py              # (legacy demo path)
  train_classifier.py               # (legacy demo path)
  export_tflite.py                  # (legacy demo path)
  generate_synthetic_demo.py        # (legacy demo path, synthetic only)
```

## What is still missing (in order)

1. **Test on a phone**: `flutter run`, real signs, all three tabs;
   fix the YUV plane order / thresholds if a device disagrees.
2. Add verified Learn reference images and Urdu TTS.
3. Only after the alphabet is solid: sequences, two hands, and words
   — the road to fuller PSL, not a claim made today.
4. (Done, kept for the record) Download a real dataset and run the
   real training — see "Dataset" and "Honest status" above.
