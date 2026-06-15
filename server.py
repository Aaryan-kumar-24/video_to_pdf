import os
import sys
import uuid
import shutil
import tempfile
import subprocess

from fastapi import FastAPI, UploadFile, File
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

app = FastAPI(
    title="Video-to-PDF API",
    description="Convert notes videos into PDF documents",
    version="1.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==========================
# FLUTTER WEB CONFIGURATION
# ==========================

STATIC_DIR = "static"

if os.path.exists(STATIC_DIR):
    app.mount(
        "/assets",
        StaticFiles(directory="static/assets"),
        name="assets"
    )

    if os.path.exists("static/canvaskit"):
        app.mount(
            "/canvaskit",
            StaticFiles(directory="static/canvaskit"),
            name="canvaskit"
        )


@app.get("/health")
def health():
    return {"status": "healthy"}


# ==========================
# API ENDPOINT
# ==========================

@app.post("/api/convert")
async def convert_video(file: UploadFile = File(...)):
    temp_dir = tempfile.mkdtemp()

    try:
        extension = os.path.splitext(file.filename)[1]

        if not extension:
            extension = ".mp4"

        video_path = os.path.join(
            temp_dir,
            f"input_video{extension}"
        )

        with open(video_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        pdf_path = os.path.join(
            temp_dir,
            f"output_{uuid.uuid4().hex}.pdf"
        )

        current_dir = os.path.dirname(
            os.path.abspath(__file__)
        )

        script_path = os.path.join(
            current_dir,
            "a.py"
        )

        if not os.path.exists(script_path):
            return JSONResponse(
                status_code=500,
                content={
                    "error": "a.py not found"
                }
            )

        result = subprocess.run(
            [
                sys.executable,
                script_path,
                video_path,
                pdf_path
            ],
            cwd=current_dir,
            capture_output=True,
            text=True
        )

        print("STDOUT:")
        print(result.stdout)

        print("STDERR:")
        print(result.stderr)

        if result.returncode != 0:
            return JSONResponse(
                status_code=500,
                content={
                    "error": "Video processing failed",
                    "details": result.stderr
                }
            )

        if not os.path.exists(pdf_path):
            return JSONResponse(
                status_code=500,
                content={
                    "error": "PDF was not generated"
                }
            )

        return FileResponse(
            path=pdf_path,
            media_type="application/pdf",
            filename="converted_notes.pdf"
        )

    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={
                "error": str(e)
            }
        )


# ==========================
# FLUTTER WEB ROUTES
# ==========================

@app.get("/")
async def frontend():
    return FileResponse("static/index.html")


@app.get("/{full_path:path}")
async def serve_flutter(full_path: str):

    file_path = os.path.join(
        "static",
        full_path
    )

    if os.path.isfile(file_path):
        return FileResponse(file_path)

    return FileResponse("static/index.html")


if __name__ == "__main__":
    import uvicorn

    port = int(
        os.environ.get(
            "PORT",
            8000
        )
    )

    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=port
    )