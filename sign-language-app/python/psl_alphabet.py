"""The 37-letter PSL alphabet used by this project.

Each entry is (folder slug, Urdu glyph, Roman name).

Why 37 and not 39: the published PSL alphabet datasets cited in the
README use a 37-letter set. The do-chashmi he (ھ) is not a separate
class in that set, so it is not included here either. Do NOT add a
38th class by guessing — if a dataset you download uses a different
set, reconcile it explicitly and update this list, labels.txt and the
Flutter alphabet together.

The slug is the dataset folder name AND the class name in labels.txt.
Keep this file, labels.txt and flutter_app/lib/models/psl_alphabet.dart
in sync: same 37 slugs, same order.
"""

PSL_ALPHABET = [
    ("alif", "ا", "Alif"),
    ("bay", "ب", "Bay"),
    ("pay", "پ", "Pay"),
    ("tay", "ت", "Tay"),
    ("tey", "ٹ", "Tey"),
    ("say", "ث", "Say"),
    ("jeem", "ج", "Jeem"),
    ("chay", "چ", "Chay"),
    ("hay", "ح", "Hay"),
    ("khay", "خ", "Khay"),
    ("daal", "د", "Daal"),
    ("ddaal", "ڈ", "Ddaal"),
    ("zaal", "ذ", "Zaal"),
    ("ray", "ر", "Ray"),
    ("rray", "ڑ", "Rray"),
    ("zay", "ز", "Zay"),
    ("zhay", "ژ", "Zhay"),
    ("seen", "س", "Seen"),
    ("sheen", "ش", "Sheen"),
    ("saad", "ص", "Saad"),
    ("zaad", "ض", "Zaad"),
    ("toa", "ط", "Toa"),
    ("zoa", "ظ", "Zoa"),
    ("ain", "ع", "Ain"),
    ("ghain", "غ", "Ghain"),
    ("fay", "ف", "Fay"),
    ("qaaf", "ق", "Qaaf"),
    ("kaaf", "ک", "Kaaf"),
    ("gaaf", "گ", "Gaaf"),
    ("laam", "ل", "Laam"),
    ("meem", "م", "Meem"),
    ("noon", "ن", "Noon"),
    ("wao", "و", "Wao"),
    ("gol_hay", "ہ", "Gol Hay"),
    ("hamza", "ء", "Hamza"),
    ("ye", "ی", "Ye"),
    ("bari_ye", "ے", "Bari Ye"),
]

SLUGS = [slug for slug, _, _ in PSL_ALPHABET]

BY_SLUG = {slug: (urdu, roman) for slug, urdu, roman in PSL_ALPHABET}

# Image extensions counted as dataset samples.
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
