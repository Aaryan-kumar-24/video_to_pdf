import cv2
import os
import imagehash
from PIL import Image
import numpy as np

import sys

# =====================================
# CONFIG
# =====================================

VIDEO_PATH = sys.argv[1] if len(sys.argv) > 1 else "demo1.mp4"

PDF_NAME = sys.argv[2] if len(sys.argv) > 2 else "notes_output.pdf"

OUTPUT_FOLDER = sys.argv[3] if len(sys.argv) > 3 else "extracted_pages"

FRAME_SKIP = 26

HASH_THRESHOLD = 17

BLUR_THRESHOLD = 100

JPEG_QUALITY = 100

# =====================================
# CREATE FOLDER
# =====================================

os.makedirs(OUTPUT_FOLDER, exist_ok=True)

for f in os.listdir(OUTPUT_FOLDER):

    path = os.path.join(OUTPUT_FOLDER, f)

    if os.path.isfile(path):
        os.remove(path)

# =====================================
# BLUR CHECK
# =====================================

def is_blurry(frame):

    gray = cv2.cvtColor(
        frame,
        cv2.COLOR_BGR2GRAY
    )

    blur_score = cv2.Laplacian(
        gray,
        cv2.CV_64F
    ).var()

    return blur_score < BLUR_THRESHOLD

# =====================================
# CENTER CROP
# =====================================

def crop_center(frame):

    h, w = frame.shape[:2]

    cropped = frame[
        int(h * 0.1):int(h * 0.9),
        int(w * 0.1):int(w * 0.9)
    ]

    return cropped

# =====================================
# HASH GENERATION
# =====================================

def get_hash(frame):

    cropped = crop_center(frame)

    rgb = cv2.cvtColor(
        cropped,
        cv2.COLOR_BGR2RGB
    )

    pil_img = Image.fromarray(rgb)

    return imagehash.phash(pil_img)

# =====================================
# UNIQUE CHECK
# =====================================

def is_unique(new_hash, hashes):

    if len(hashes) == 0:
        return True

    for old_hash in hashes:

        difference = new_hash - old_hash

        print("Hash Difference:", difference)

        if difference < HASH_THRESHOLD:
            return False

    return True

# =====================================
# VIDEO PROCESSING
# =====================================

cap = cv2.VideoCapture(VIDEO_PATH)

frame_count = 0

saved_count = 0

saved_hashes = []

saved_images = []

print("Processing video...")

while True:

    ret, frame = cap.read()

    if not ret:
        break

    frame_count += 1

    if frame_count % FRAME_SKIP != 0:
        continue

    if is_blurry(frame):
        continue

    cropped = crop_center(frame)

    current_hash = get_hash(cropped)

    if not is_unique(current_hash, saved_hashes):
        continue

    filename = os.path.join(
        OUTPUT_FOLDER,
        f"page_{saved_count+1}.jpg"
    )

    cv2.imwrite(
        filename,
        cropped,
        [
            cv2.IMWRITE_JPEG_QUALITY,
            JPEG_QUALITY
        ]
    )

    print(f"Saved unique page: {filename}")

    saved_hashes.append(current_hash)

    saved_images.append(filename)

    saved_count += 1

cap.release()

print(f"\nTotal unique pages: {saved_count}")

# =====================================
# CREATE PDF
# =====================================

images = []

for file in saved_images:

    img = Image.open(file)

    img = img.convert("RGB")

    images.append(img)

if len(images) > 0:

    first = images[0]

    rest = images[1:]

    first.save(
        PDF_NAME,
        save_all=True,
        append_images=rest
    )

    print(f"\nPDF saved as: {PDF_NAME}")

else:

    print("\nNo unique pages found.")