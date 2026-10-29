/// The 37-letter PSL alphabet.
///
/// This list MUST match, slug for slug and in the same order,
/// `python/psl_alphabet.py` and the `labels.txt` produced by
/// `python/train_psl.py`. The training script writes labels in this
/// order, so the model output index for a letter is its position in
/// this list only when labels.txt matches it — the classifier service
/// verifies labels.txt against this list at load time and refuses to
/// run if they disagree, rather than silently mislabelling signs.
///
/// Why 37: the published PSL alphabet datasets cited in the README
/// use a 37-letter set (the do-chashmi he, ھ, is not a separate class
/// in that set). Do not add classes by guessing.
class PslLetter {
  const PslLetter(this.slug, this.urdu, this.roman);

  /// Folder name in the dataset and class name in labels.txt.
  final String slug;

  /// Urdu glyph, shown in the app UI.
  final String urdu;

  /// Roman name, spoken by text-to-speech and shown in Learn mode.
  final String roman;
}

const pslAlphabet = <PslLetter>[
  PslLetter('alif', 'ا', 'Alif'),
  PslLetter('bay', 'ب', 'Bay'),
  PslLetter('pay', 'پ', 'Pay'),
  PslLetter('tay', 'ت', 'Tay'),
  PslLetter('tey', 'ٹ', 'Tey'),
  PslLetter('say', 'ث', 'Say'),
  PslLetter('jeem', 'ج', 'Jeem'),
  PslLetter('chay', 'چ', 'Chay'),
  PslLetter('hay', 'ح', 'Hay'),
  PslLetter('khay', 'خ', 'Khay'),
  PslLetter('daal', 'د', 'Daal'),
  PslLetter('ddaal', 'ڈ', 'Ddaal'),
  PslLetter('zaal', 'ذ', 'Zaal'),
  PslLetter('ray', 'ر', 'Ray'),
  PslLetter('rray', 'ڑ', 'Rray'),
  PslLetter('zay', 'ز', 'Zay'),
  PslLetter('zhay', 'ژ', 'Zhay'),
  PslLetter('seen', 'س', 'Seen'),
  PslLetter('sheen', 'ش', 'Sheen'),
  PslLetter('saad', 'ص', 'Saad'),
  PslLetter('zaad', 'ض', 'Zaad'),
  PslLetter('toa', 'ط', 'Toa'),
  PslLetter('zoa', 'ظ', 'Zoa'),
  PslLetter('ain', 'ع', 'Ain'),
  PslLetter('ghain', 'غ', 'Ghain'),
  PslLetter('fay', 'ف', 'Fay'),
  PslLetter('qaaf', 'ق', 'Qaaf'),
  PslLetter('kaaf', 'ک', 'Kaaf'),
  PslLetter('gaaf', 'گ', 'Gaaf'),
  PslLetter('laam', 'ل', 'Laam'),
  PslLetter('meem', 'م', 'Meem'),
  PslLetter('noon', 'ن', 'Noon'),
  PslLetter('wao', 'و', 'Wao'),
  PslLetter('gol_hay', 'ہ', 'Gol Hay'),
  PslLetter('hamza', 'ء', 'Hamza'),
  PslLetter('ye', 'ی', 'Ye'),
  PslLetter('bari_ye', 'ے', 'Bari Ye'),
];

PslLetter? pslLetterBySlug(String slug) {
  for (final letter in pslAlphabet) {
    if (letter.slug == slug) return letter;
  }
  return null;
}
