import os
import sys
import uuid
import shutil
import tempfile
import subprocess
import json
import time
from typing import List
from PIL import Image

from fastapi import FastAPI, UploadFile, File, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

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

class RegeneratePDFRequest(BaseModel):
    session_id: str
    remaining_pages: List[int]

def compile_pdf_from_images(image_paths, output_pdf_path):
    images = []
    for path in image_paths:
        if os.path.exists(path):
            img = Image.open(path)
            img = img.convert("RGB")
            images.append(img)
    if len(images) > 0:
        first = images[0]
        rest = images[1:]
        first.save(
            output_pdf_path,
            save_all=True,
            append_images=rest
        )
        return True
    return False

@app.post("/api/convert")
async def convert_video(request: Request, file: UploadFile = File(...)):
    session_id = uuid.uuid4().hex
    session_dir = os.path.join("static", "sessions", session_id)
    pages_dir = os.path.join(session_dir, "pages")
    os.makedirs(pages_dir, exist_ok=True)
    
    temp_dir = tempfile.mkdtemp()
    
    try:
        extension = os.path.splitext(file.filename)[1]
        if not extension:
            extension = ".mp4"
            
        video_path = os.path.join(temp_dir, f"input_video{extension}")
        
        with open(video_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        pdf_path = os.path.join(session_dir, "original.pdf")
        
        current_dir = os.path.dirname(os.path.abspath(__file__))
        script_path = os.path.join(current_dir, "a.py")
        
        if not os.path.exists(script_path):
            return JSONResponse(
                status_code=500,
                content={"error": "a.py not found"}
            )
            
        result = subprocess.run(
            [
                sys.executable,
                script_path,
                video_path,
                pdf_path,
                pages_dir
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
                content={"error": "PDF was not generated (possibly no unique frames)"}
            )
            
        files = os.listdir(pages_dir)
        jpg_files = [f for f in files if f.endswith(".jpg")]
        jpg_files.sort(key=lambda x: int(x.split("_")[1].split(".")[0]))
        
        pages = []
        for f in jpg_files:
            page_num = int(f.split("_")[1].split(".")[0])
            pages.append({
                "page_number": page_num,
                "image_path": os.path.join(pages_dir, f)
            })
            
        session_info = {
            "session_id": session_id,
            "original_pdf": f"/sessions/{session_id}/original.pdf",
            "current_pdf": f"/sessions/{session_id}/original.pdf",
            "pages": pages
        }
        
        with open(os.path.join(session_dir, "session.json"), "w") as sf:
            json.dump(session_info, sf)
            
        shutil.rmtree(temp_dir, ignore_errors=True)
        
        base_url = str(request.base_url)
        formatted_pages = []
        for p in pages:
            img_name = os.path.basename(p["image_path"])
            formatted_pages.append({
                "page_number": p["page_number"],
                "image_url": f"{base_url}sessions/{session_id}/pages/{img_name}"
            })
            
        return {
            "session_id": session_id,
            "pdf_url": f"{base_url}sessions/{session_id}/original.pdf",
            "pages": formatted_pages
        }
        
    except Exception as e:
        shutil.rmtree(temp_dir, ignore_errors=True)
        return JSONResponse(
            status_code=500,
            content={"error": str(e)}
        )

@app.get("/session/{session_id}")
async def get_session(session_id: str, request: Request):
    session_dir = os.path.join("static", "sessions", session_id)
    session_json_path = os.path.join(session_dir, "session.json")
    if not os.path.exists(session_json_path):
        return JSONResponse(status_code=404, content={"error": "Session not found"})
        
    with open(session_json_path, "r") as f:
        session_data = json.load(f)
        
    base_url = str(request.base_url)
    formatted_pages = []
    for page in session_data["pages"]:
        img_name = os.path.basename(page["image_path"])
        formatted_pages.append({
            "page_number": page["page_number"],
            "image_url": f"{base_url}sessions/{session_id}/pages/{img_name}"
        })
        
    current_pdf_filename = os.path.basename(session_data["current_pdf"])
    
    return {
        "session_id": session_id,
        "pdf_url": f"{base_url}sessions/{session_id}/{current_pdf_filename}",
        "pages": formatted_pages
    }

@app.post("/regenerate-pdf")
async def regenerate_pdf(req: RegeneratePDFRequest, request: Request):
    session_id = req.session_id
    remaining_pages = req.remaining_pages
    
    session_dir = os.path.join("static", "sessions", session_id)
    session_json_path = os.path.join(session_dir, "session.json")
    
    if not os.path.exists(session_json_path):
        return JSONResponse(status_code=404, content={"error": "Session not found"})
        
    with open(session_json_path, "r") as f:
        session_data = json.load(f)
        
    if not remaining_pages:
        return JSONResponse(
            status_code=400,
            content={"error": "Cannot regenerate PDF with 0 pages. At least one page is required."}
        )
        
    image_paths = []
    page_map = {p["page_number"]: p["image_path"] for p in session_data["pages"]}
    
    for page_num in remaining_pages:
        if page_num in page_map:
            image_paths.append(page_map[page_num])
        else:
            return JSONResponse(
                status_code=400,
                content={"error": f"Page number {page_num} not found in session."}
            )
            
    timestamp = int(time.time())
    new_pdf_filename = f"edited_{timestamp}.pdf"
    new_pdf_path = os.path.join(session_dir, new_pdf_filename)
    
    success = compile_pdf_from_images(image_paths, new_pdf_path)
    if not success:
        return JSONResponse(
            status_code=500,
            content={"error": "Failed to compile new PDF from remaining pages"}
        )
        
    session_data["current_pdf"] = f"/sessions/{session_id}/{new_pdf_filename}"
    with open(session_json_path, "w") as f:
        json.dump(session_data, f)
        
    base_url = str(request.base_url)
    return {
        "success": True,
        "edited_pdf_url": f"{base_url}sessions/{session_id}/{new_pdf_filename}"
    }

@app.get("/download/{session_id}")
async def download_pdf(session_id: str):
    session_dir = os.path.join("static", "sessions", session_id)
    session_json_path = os.path.join(session_dir, "session.json")
    if not os.path.exists(session_json_path):
        return JSONResponse(status_code=404, content={"error": "Session not found"})
        
    with open(session_json_path, "r") as f:
        session_data = json.load(f)
        
    pdf_rel_path = session_data["current_pdf"].lstrip("/")
    pdf_path = os.path.join("static", pdf_rel_path)
    
    if not os.path.exists(pdf_path):
        pdf_path = os.path.join(session_dir, "original.pdf")
        
    return FileResponse(
        path=pdf_path,
        media_type="application/pdf",
        filename="converted_notes.pdf"
    )

@app.get("/preview/{session_id}")
async def preview_pdf(session_id: str):
    session_dir = os.path.join("static", "sessions", session_id)
    session_json_path = os.path.join(session_dir, "session.json")
    if not os.path.exists(session_json_path):
        return JSONResponse(status_code=404, content={"error": "Session not found"})
        
    with open(session_json_path, "r") as f:
        session_data = json.load(f)
        
    pdf_rel_path = session_data["current_pdf"].lstrip("/")
    pdf_path = os.path.join("static", pdf_rel_path)
    
    if not os.path.exists(pdf_path):
        pdf_path = os.path.join(session_dir, "original.pdf")
        
    return FileResponse(
        path=pdf_path,
        media_type="application/pdf"
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