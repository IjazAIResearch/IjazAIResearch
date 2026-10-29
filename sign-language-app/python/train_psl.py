#!/usr/bin/env python3
"""Train the full PSL alphabet image classifier (transfer learning).

Input : an image dataset laid out as data/psl_images/<slug>/*.jpg
        (one folder per letter; see prepare_dataset.py and README.md).
Output: <output-dir>/model.tflite  (quantized, for the Flutter app)
        <output-dir>/labels.txt    (one class slug per line, in the
                                    order the model outputs them)
        <output-dir>/test_report.txt (held-out classification report
                                      + confusion matrix)
        <output-dir>/history.json  (training curves)

Model: MobileNetV2 (ImageNet weights), 224x224 input, frozen base +
a new classification head, then a short fine-tuning phase with the
top layers unfrozen at a low learning rate.

Splits (stratified, so every class keeps its share in every split):
test 15% is held out first, then the remainder is split into train
and validation so validation is ~15% of the total. Roughly 70/15/15.

Honesty rules built into this script:
  * If the dataset folder is missing or empty, it exits with a clear
    message BEFORE importing TensorFlow — no fake training run.
  * By default it refuses to train unless all 37 classes are present.
    Pass --allow-partial to train on fewer classes anyway; labels.txt
    will then list only the trained classes, and the app will only
    recognise those letters. That is a smaller model, not a 37-letter
    model — the report says so.
  * The only accuracy ever reported is measured on the held-out test
    split. Nothing is claimed about signs, signers or lighting that
    are not in that test set.

Usage:
    python prepare_dataset.py --data-dir data/psl_images
    python train_psl.py --data-dir data/psl_images --output-dir output
    # then copy output/model.tflite + output/labels.txt into
    # flutter_app/assets/ and enable the assets block in pubspec.yaml

Requirements: pip install -r requirements.txt
(tensorflow, scikit-learn, pandas, numpy, pillow)
"""

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from psl_alphabet import IMAGE_EXTENSIONS, PSL_ALPHABET  # noqa: E402


def collect_samples(data_dir):
    """Return {slug: [image paths]} using only the standard library."""
    samples = {}
    for slug, _, _ in PSL_ALPHABET:
        folder = os.path.join(data_dir, slug)
        if not os.path.isdir(folder):
            continue
        paths = []
        for root, _, files in os.walk(folder):
            for name in sorted(files):
                if os.path.splitext(name)[1].lower() in IMAGE_EXTENSIONS:
                    paths.append(os.path.join(root, name))
        if paths:
            samples[slug] = paths
    return samples


def validate_dataset(data_dir, allow_partial):
    if not os.path.isdir(data_dir):
        print(f"DATASET FOLDER IS EMPTY / MISSING: '{data_dir}' does not "
              "exist.")
        print("Download a published PSL alphabet dataset (see README.md, "
              "'Dataset' section) and place one folder per letter here "
              "first. Nothing was trained.")
        return None
    samples = collect_samples(data_dir)
    total = sum(len(v) for v in samples.values())
    if total == 0:
        print(f"DATASET FOLDER IS EMPTY: '{data_dir}' contains no images "
              "for any of the 37 PSL letters.")
        print("Download a published PSL alphabet dataset (see README.md, "
              "'Dataset' section) and place one folder per letter here "
              "first. Nothing was trained.")
        return None
    missing = [slug for slug, _, _ in PSL_ALPHABET if slug not in samples]
    if missing and not allow_partial:
        print("REFUSING TO TRAIN: the following classes have no images:")
        for slug in missing:
            print(f"  - {slug}")
        print("Add images for these classes, or re-run with "
              "--allow-partial to train a model covering only the "
              f"{len(samples)} classes present.")
        return None
    if missing:
        print(f"WARNING: training a PARTIAL model on {len(samples)} of 37 "
              f"classes; missing: {', '.join(missing)}")
    # Stratified splitting needs at least 2 samples per class; with 1
    # sample a class cannot appear in every split.
    thin = [s for s, v in samples.items() if len(v) < 3]
    if thin:
        print("REFUSING TO TRAIN: these classes have fewer than 3 images, "
              "so a stratified train/val/test split is impossible:")
        for slug in thin:
            print(f"  - {slug} ({len(samples[slug])} images)")
        print("Add at least 3 images per class (more is much better).")
        return None
    print(f"Dataset OK: {total} images across {len(samples)} classes.")
    return samples


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", default="data/psl_images",
                        help="Folder with one subfolder per PSL letter")
    parser.add_argument("--output-dir", default="output",
                        help="Where to write model.tflite, labels.txt, "
                             "test_report.txt, history.json")
    parser.add_argument("--epochs", type=int, default=15,
                        help="Epochs for the head-training phase")
    parser.add_argument("--fine-tune-epochs", type=int, default=10,
                        help="Epochs for the fine-tuning phase (0 to skip)")
    parser.add_argument("--unfreeze-layers", type=int, default=30,
                        help="Top base-model layers to unfreeze for "
                             "fine-tuning")
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--full-integer", action="store_true",
                        help="Full-integer TFLite quantization (needs a "
                             "representative dataset; slower, smaller, "
                             "may cost a little accuracy). Default is "
                             "dynamic-range quantization.")
    parser.add_argument("--allow-partial", action="store_true",
                        help="Train even if some of the 37 classes are "
                             "missing (see honesty rules above)")
    args = parser.parse_args()

    # Validate BEFORE importing TensorFlow so a missing dataset fails
    # fast with a clear message, not an import error.
    samples = validate_dataset(args.data_dir, args.allow_partial)
    if samples is None:
        return 2

    import numpy as np
    import pandas as pd
    import tensorflow as tf
    from sklearn.metrics import classification_report, confusion_matrix
    from sklearn.model_selection import train_test_split
    from sklearn.utils.class_weight import compute_class_weight
    from tensorflow.keras.applications import MobileNetV2
    from tensorflow.keras.applications.mobilenet_v2 import preprocess_input
    from tensorflow.keras.layers import Dense, Dropout, GlobalAveragePooling2D
    from tensorflow.keras.models import Model
    from tensorflow.keras.preprocessing.image import ImageDataGenerator

    # Labels in PSL_ALPHABET order (only the classes actually present).
    class_slugs = [s for s, _, _ in PSL_ALPHABET if s in samples]
    num_classes = len(class_slugs)
    print(f"Classes ({num_classes}): {class_slugs}")

    rows = [(path, slug) for slug in class_slugs for path in samples[slug]]
    df = pd.DataFrame(rows, columns=["filename", "class"])

    # Stratified splits: test 15%, then val ~15% of the total.
    train_val, test = train_test_split(
        df, test_size=0.15, random_state=42, stratify=df["class"])
    train, val = train_test_split(
        train_val, test_size=0.1765, random_state=42,
        stratify=train_val["class"])
    print(f"Split sizes — train: {len(train)}, val: {len(val)}, "
          f"test: {len(test)}")

    train_gen = ImageDataGenerator(
        preprocessing_function=preprocess_input,
        rotation_range=15, width_shift_range=0.1, height_shift_range=0.1,
        zoom_range=0.1, horizontal_flip=True)
    plain_gen = ImageDataGenerator(preprocessing_function=preprocess_input)

    def make_flow(frame, gen, shuffle):
        return gen.flow_from_dataframe(
            frame, x_col="filename", y_col="class",
            target_size=(224, 224), batch_size=args.batch_size,
            class_mode="categorical", classes=class_slugs, shuffle=shuffle)

    train_flow = make_flow(train, train_gen, shuffle=True)
    val_flow = make_flow(val, plain_gen, shuffle=False)
    test_flow = make_flow(test, plain_gen, shuffle=False)

    # Class weights so rare letters are not ignored.
    weights = compute_class_weight(
        "balanced", classes=np.array(class_slugs), y=train["class"])
    class_weight = {i: float(w) for i, w in enumerate(weights)}

    base = MobileNetV2(weights="imagenet", include_top=False,
                       input_shape=(224, 224, 3))
    base.trainable = False
    x = GlobalAveragePooling2D()(base.output)
    x = Dropout(0.3)(x)
    out = Dense(num_classes, activation="softmax")(x)
    model = Model(base.input, out)
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                  loss="categorical_crossentropy", metrics=["accuracy"])
    print("Phase 1: training classification head (base frozen)…")
    history1 = model.fit(train_flow, validation_data=val_flow,
                         epochs=args.epochs, class_weight=class_weight)
    history = {"head": history1.history}

    if args.fine_tune_epochs > 0:
        for layer in base.layers[-args.unfreeze_layers:]:
            layer.trainable = True
        model.compile(optimizer=tf.keras.optimizers.Adam(1e-5),
                      loss="categorical_crossentropy",
                      metrics=["accuracy"])
        print(f"Phase 2: fine-tuning top {args.unfreeze_layers} layers…")
        history2 = model.fit(train_flow, validation_data=val_flow,
                             epochs=args.fine_tune_epochs,
                             class_weight=class_weight)
        history["fine_tune"] = history2.history

    # Held-out evaluation — the ONLY accuracy this project reports.
    test_flow.reset()
    preds = model.predict(test_flow, verbose=0)
    y_pred = np.argmax(preds, axis=1)
    y_true = test_flow.classes
    report = classification_report(y_true, y_pred,
                                   target_names=class_slugs, zero_division=0)
    cm = confusion_matrix(y_true, y_pred)
    print("\n=== HELD-OUT TEST REPORT (this is the real result) ===")
    print(report)
    print("Confusion matrix (rows = true, columns = predicted):")
    print(cm)

    os.makedirs(args.output_dir, exist_ok=True)
    with open(os.path.join(args.output_dir, "labels.txt"), "w",
              encoding="utf-8") as f:
        f.write("\n".join(class_slugs) + "\n")
    with open(os.path.join(args.output_dir, "test_report.txt"), "w",
              encoding="utf-8") as f:
        f.write(f"Classes trained: {num_classes} — {class_slugs}\n")
        f.write(f"Test set size: {len(test)}\n\n{report}\n")
        f.write("Confusion matrix (rows = true, columns = predicted):\n")
        f.write(str(cm) + "\n")
    with open(os.path.join(args.output_dir, "history.json"), "w",
              encoding="utf-8") as f:
        json.dump(history, f, indent=2)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    if args.full_integer:
        rep = train["filename"].sample(
            n=min(500, len(train)), random_state=42).tolist()

        def representative_data():
            for path in rep:
                img = tf.keras.utils.load_img(path, target_size=(224, 224))
                arr = tf.keras.utils.img_to_array(img)
                arr = preprocess_input(arr)
                yield [np.expand_dims(arr, axis=0).astype(np.float32)]

        converter.representative_dataset = representative_data
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        converter.inference_input_type = tf.uint8
        converter.inference_output_type = tf.uint8
    tflite_model = converter.convert()
    tflite_path = os.path.join(args.output_dir, "model.tflite")
    with open(tflite_path, "wb") as f:
        f.write(tflite_model)
    print(f"\nSaved: {tflite_path} ({len(tflite_model)} bytes)")
    print(f"Saved: {os.path.join(args.output_dir, 'labels.txt')}")
    print("Next: copy model.tflite + labels.txt into flutter_app/assets/ "
          "and enable the assets block in flutter_app/pubspec.yaml.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
