#!/usr/bin/env python3
"""Inspect a PSL alphabet image dataset and report per-class counts.

Expected layout (see README.md for where to download a dataset)::

    data/psl_images/
        alif/*.jpg
        bay/*.jpg
        ... (one folder per slug in psl_alphabet.PSL_ALPHABET)

Usage:
    python prepare_dataset.py
    python prepare_dataset.py --data-dir path/to/psl_images

Behaviour — no data is invented here:
  * If the folder is missing or contains no images at all, the script
    prints a clear message saying the dataset folder is empty and
    exits with code 2. This is the expected state before a dataset
    has been downloaded; it is not an error in the code.
  * If some classes are missing or empty, it lists them and exits
    with code 1.
  * If every class has at least one image, it prints the full table
    and exits with code 0. A class with very few images is flagged
    as a warning only — the number itself is reported, not hidden.

The script only counts files. It does not decode images, does not
generate samples and does not claim anything about image quality.
Downloaded datasets use their own folder names, so a folder whose
name is not one of the 37 slugs is reported as "unrecognised" —
rename such folders to the matching slug before training.

Standard library only: this script always runs, even without
TensorFlow installed.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from psl_alphabet import IMAGE_EXTENSIONS, PSL_ALPHABET, SLUGS  # noqa: E402

# Below this count, a class is flagged so the user can decide whether
# to collect more samples for it. This is a warning threshold, not a
# claim that fewer samples cannot train.
FEW_SAMPLES_WARNING = 50


def count_images(folder):
    total = 0
    for root, _, files in os.walk(folder):
        for name in files:
            if os.path.splitext(name)[1].lower() in IMAGE_EXTENSIONS:
                total += 1
    return total


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", default="data/psl_images",
                        help="Folder with one subfolder per PSL letter "
                             "(default: data/psl_images)")
    args = parser.parse_args()

    data_dir = args.data_dir
    if not os.path.isdir(data_dir):
        print(f"DATASET FOLDER IS EMPTY / MISSING: '{data_dir}' does not "
              "exist.")
        print("No dataset has been placed here yet. Download a published "
              "PSL alphabet dataset (see README.md, 'Dataset' section), "
              "then put one folder per letter under this directory and "
              "re-run this script.")
        return 2

    counts = {}
    for slug, urdu, roman in PSL_ALPHABET:
        folder = os.path.join(data_dir, slug)
        counts[slug] = count_images(folder) if os.path.isdir(folder) else 0

    # Folders present on disk that are not one of the 37 slugs.
    unrecognised = []
    if os.path.isdir(data_dir):
        for entry in sorted(os.listdir(data_dir)):
            full = os.path.join(data_dir, entry)
            if os.path.isdir(full) and entry not in SLUGS:
                unrecognised.append(entry)

    total = sum(counts.values())
    if total == 0:
        print(f"DATASET FOLDER IS EMPTY: '{data_dir}' contains no images "
              "for any of the 37 PSL letters.")
        print("Download a published PSL alphabet dataset (see README.md, "
              "'Dataset' section), place one folder per letter here, and "
              "re-run this script.")
        return 2

    print(f"Dataset: {data_dir}")
    print(f"{'slug':<10}{'letter':<8}{'roman':<10}{'images':>8}")
    print("-" * 38)
    missing = []
    few = []
    for slug, urdu, roman in PSL_ALPHABET:
        n = counts[slug]
        print(f"{slug:<10}{urdu:<8}{roman:<10}{n:>8}")
        if n == 0:
            missing.append(slug)
        elif n < FEW_SAMPLES_WARNING:
            few.append((slug, n))
    print("-" * 38)
    print(f"Total images: {total} across {len(PSL_ALPHABET)} classes")

    if unrecognised:
        print("\nUNRECOGNISED folders (not one of the 37 slugs, ignored "
              "by training):")
        for name in unrecognised:
            print(f"  - {name}  (rename it to the matching slug, or "
                  "remove it if it is a word class)")

    if few:
        print("\nWARNING — classes with few samples "
              f"(fewer than {FEW_SAMPLES_WARNING}):")
        for slug, n in few:
            print(f"  - {slug}: {n} images")

    if missing:
        print("\nMISSING / EMPTY classes (no images found):")
        for slug in missing:
            print(f"  - {slug}")
        print("Add images for these classes before training the full "
              "37-letter model, or train with --allow-partial (see "
              "train_psl.py) and accept a model that covers fewer "
              "letters.")
        return 1

    print("\nAll 37 classes present. Ready to train: "
          "python train_psl.py --data-dir " + data_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
