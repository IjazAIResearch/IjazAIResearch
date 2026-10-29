# App assets — added AFTER training

This folder is intentionally empty in the repo. After training:

1. Copy `model.tflite` and `labels.txt` from `python/output/` here.
2. Uncomment the `assets:` block in `flutter_app/pubspec.yaml`.
3. Run `flutter pub get && flutter run`.

Until then the app runs in the clearly-labelled demo fallback mode.

Optional Learn-mode reference images (one per letter, copied from the
dataset you trained on, with the dataset's licence respected):

```
assets/learn/alif.jpg
assets/learn/bay.jpg
... one file per slug in lib/models/psl_alphabet.dart ...
```

No reference image is shipped here, because no dataset has been
downloaded yet — and no handshape diagram is guessed in their place.
