# 🎥 Video-to-PDF — Intelligent Notes Scanner & PDF Generator

Video-to-PDF is an AI-powered document extraction system that converts handwritten or printed notes videos into clean PDF documents containing only unique pages.

The system processes a video frame-by-frame, detects document pages automatically, removes duplicate pages using image hashing and frame analysis, enhances the extracted pages, and generates a final PDF.

Unlike traditional screenshot-based extraction tools that produce hundreds of duplicate or blurry images, this project intelligently filters and preserves only high-quality unique pages.

Students can:

- record classroom notes as a video
- convert long note videos into PDFs
- remove duplicate pages automatically
- extract only clear pages
- generate organized study material instantly
- avoid manual screenshotting

---

# 🌍 Project Vision

Students often record notes using mobile phones during lectures or while revising notebooks.

Problems with raw video recordings:

- duplicate frames
- blurry pages
- poor lighting
- manual screenshot work
- difficult PDF creation

Traditional methods require manually taking screenshots and compiling them into PDFs.

This project automates the entire workflow using Computer Vision and intelligent duplicate detection.

---

# 🎯 Objective

The goal of Video-to-PDF is to create a smart document extraction system capable of:

- detecting pages automatically from videos
- removing duplicate pages
- extracting only high-quality frames
- generating organized PDFs
- reducing manual work
- improving digital note management

---

# 🎯 Resume-Ready Project Summary

## Video-to-PDF — AI-Based Notes Video to PDF Converter

Developed an intelligent computer vision system that converts notes videos into organized PDFs by detecting and extracting only unique document pages.

### Key Achievements

- Automatic document detection from videos
- Duplicate page removal using image hashing
- Perspective correction for scanned pages
- High-quality page extraction
- Automatic PDF generation
- Frame quality analysis using blur detection
- Intelligent frame filtering system
- Supports handwritten and printed notes

### Architecture

Computer Vision Pipeline + Image Processing Workflow

---

# 🛠 Technology Stack

## Frontend

- React.js
- Vite
- HTML5
- CSS3
- JavaScript

## Backend

- Python
- Flask

## Computer Vision & AI

- OpenCV
- NumPy
- PIL (Pillow)
- ImageHash
- MediaPipe

## PDF Generation

- PIL PDF Export

---

# 🎓 Core Problem

Traditional workflow:

```text
Notes Video
      |
      v
Manual Screenshots
      |
      v
Hundreds of Duplicate Images
      |
      v
Manual Cleanup
      |
      v
Create PDF Manually
      |
      v
Time Waste
```

## Limitations

- duplicate screenshots
- blurry frames
- poor organization
- manual effort
- large storage consumption

---

# 💡 Smart Workflow

```text
Input Notes Video
        |
        v
+----------------------+
| Video Frame Capture  |
+----------+-----------+
           |
           v
+----------------------+
| Document Detection   |
| OpenCV Contours      |
+----------+-----------+
           |
           v
+----------------------+
| Perspective Warp     |
| Page Enhancement     |
+----------+-----------+
           |
           v
+----------------------+
| Blur Detection       |
| Quality Filtering    |
+----------+-----------+
           |
           v
+----------------------+
| Duplicate Detection  |
| Image Hashing        |
+----------+-----------+
           |
           v
+----------------------+
| Unique Pages Saved   |
+----------+-----------+
           |
           v
+----------------------+
| PDF Generation       |
+----------------------+
```

---

# 🔎 Key Features

## 📄 Automatic Page Detection

The system detects notebook/document boundaries automatically using contour detection.

### Capabilities

- detects page edges
- supports handwritten notes
- supports printed pages
- real-time frame processing

---

## 🧠 Duplicate Page Removal

Duplicate pages are filtered using intelligent image hashing techniques.

### Capabilities

- compares extracted frames
- removes similar pages
- avoids repeated PDF pages
- reduces storage usage

### Built Using

- ImageHash
- Perceptual Hashing

---

## ✨ Perspective Correction

Pages are automatically aligned using perspective transformation.

### Capabilities

- fixes tilted pages
- improves readability
- generates scanner-like output

### Built Using

- OpenCV Warp Perspective

---

## 🔍 Blur Detection

Low-quality frames are skipped automatically.

### Capabilities

- detects blurry images
- keeps only sharp pages
- improves final PDF quality

### Built Using

- Laplacian Variance Method

---

## 📚 PDF Generation

All unique extracted pages are combined into a single PDF automatically.

### Capabilities

- ordered page arrangement
- high-quality PDF export
- lightweight output file

---

# 🧠 System Architecture

```text
Video Input
     |
     v
+----------------------+
| Frame Extraction     |
+----------+-----------+
           |
           v
+----------------------+
| OpenCV Processing    |
| Contour Detection    |
+----------+-----------+
           |
           v
+----------------------+
| Image Enhancement    |
| Perspective Warp     |
+----------+-----------+
           |
           v
+----------------------+
| Duplicate Detection  |
| ImageHash Comparison |
+----------+-----------+
           |
           v
+----------------------+
| Unique Page Storage  |
+----------+-----------+
           |
           v
+----------------------+
| PDF Generator        |
+----------------------+
```

---

# 📂 Project Structure

```text
demo
│
├── frontend
│   ├── public
│   ├── src
│   │   ├── App.jsx
│   │   ├── App.css
│   │   ├── index.css
│   │   ├── main.jsx
│   │   └── assets
│   │
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js
│   └── README.md
│
├── extracted_pages
│
├── a.py
├── server.py
├── readme.md
└── __pycache__
```

---

# 🚀 Deployment Architecture

```text
User Uploads Video
          |
          v
+----------------------+
| React Frontend       |
+----------+-----------+
           |
           v
+----------------------+
| Python Flask Server  |
| OpenCV Processing    |
+----------+-----------+
           |
           v
+----------------------+
| Frame Analysis       |
| Duplicate Removal    |
+----------+-----------+
           |
           v
+----------------------+
| PDF Generation       |
+----------------------+
           |
           v
Generated Notes PDF
```

---

# 🔧 Installation Guide

## Clone Repository

```bash
git clone https://github.com/Aaryan-kumar-24/video_to_pdf.git
```

---

## Navigate to Project

```bash
cd video_to_pdf
```

---

## Create Virtual Environment

```bash
python -m venv .venv
```

---

## Activate Virtual Environment

### macOS/Linux

```bash
source .venv/bin/activate
```

### Windows

```bash
.venv\Scripts\activate
```

---

## Install Python Dependencies

```bash
pip install flask opencv-python pillow numpy imagehash mediapipe
```

---

## Install Frontend Dependencies

```bash
cd frontend
npm install
```

---

## Run Backend Server

```bash
cd ..
python server.py
```

---

## Run Frontend

```bash
cd frontend
npm run dev
```

---

## Open in Browser

```text
http://localhost:5173
```

---

# 🔥 Workflow Example

1. Upload notes video
2. System extracts frames
3. Detects document pages
4. Removes blurry frames
5. Filters duplicate pages
6. Saves unique pages
7. Generates final PDF

---

# 📈 Future Improvements

- OCR text extraction
- searchable PDFs
- AI handwriting enhancement
- cloud storage support
- mobile application
- chapter segmentation
- multilingual document support
- dark shadow removal
- automatic note summarization

---

# 👨‍💻 Author

## Aryan Kumar

Computer Science Engineer  
AI Developer | Full Stack Developer

### GitHub

https://github.com/Aaryan-kumar-24

---

# ⭐ Support

If you like this project, consider starring the repository.

```bash
⭐ Star the repo to support the project
```