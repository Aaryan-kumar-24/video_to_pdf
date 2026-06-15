import os
import subprocess
import tempfile
from fastapi import FastAPI, UploadFile, File
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import shutil
import uuid

app = FastAPI()

# Enable CORS for the React frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Adjust in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
@app.get("/")
def home():
    return {
        "status": "running",
        "message": "Video-to-PDF API deployed successfully"
    }
@app.post("/api/convert")
async def convert_video(file: UploadFile = File(...)):
    # Create a unique temporary directory for this conversion
    temp_dir = tempfile.mkdtemp()
    
    # Save the uploaded video
    video_ext = os.path.splitext(file.filename)[1]
    if not video_ext:
        video_ext = ".mp4"
    
    video_path = os.path.join(temp_dir, f"input_video{video_ext}")
    
    with open(video_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # Define output PDF path
    pdf_filename = f"output_{uuid.uuid4().hex}.pdf"
    pdf_path = os.path.join(temp_dir, pdf_filename)
    
    # Call a.py
    # Make sure to run it from the same directory where a.py is located
    current_dir = os.path.dirname(os.path.abspath(__file__))
    script_path = os.path.join(current_dir, "a.py")
    
    try:
        # Run a.py as a subprocess
        result = subprocess.run(
            ["python", script_path, video_path, pdf_path],
            cwd=current_dir,
            capture_output=True,
            text=True,
            check=True
        )
        print("Subprocess output:", result.stdout)
    except subprocess.CalledProcessError as e:
        print("Subprocess error:", e.stderr)
        return {"error": "Failed to process video", "details": e.stderr}
        
    if not os.path.exists(pdf_path):
        return {"error": "PDF was not generated"}
        
    # Return the PDF file
    return FileResponse(
        path=pdf_path,
        media_type="application/pdf",
        filename="converted_notes.pdf"
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host="0.0.0.0", port=8000, reload=True)
