import React, { useState, useRef } from 'react';
import { UploadCloud, FileVideo, X, CheckCircle, Download, AlertCircle, Eye } from 'lucide-react';
import './index.css';

function App() {
  const [file, setFile] = useState(null);
  const [isDragging, setIsDragging] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [pdfUrl, setPdfUrl] = useState(null);
  const [error, setError] = useState(null);
  const fileInputRef = useRef(null);

  const handleDragOver = (e) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = () => {
    setIsDragging(false);
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setIsDragging(false);
    
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      validateAndSetFile(e.dataTransfer.files[0]);
    }
  };

  const handleFileChange = (e) => {
    if (e.target.files && e.target.files[0]) {
      validateAndSetFile(e.target.files[0]);
    }
  };

  const validateAndSetFile = (selectedFile) => {
    setError(null);
    if (selectedFile.type.startsWith('video/')) {
      setFile(selectedFile);
      setPdfUrl(null);
    } else {
      setError('Please select a valid video file.');
    }
  };

  const clearFile = () => {
    setFile(null);
    setPdfUrl(null);
    setError(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const handleConvert = async () => {
    if (!file) return;

    setIsProcessing(true);
    setError(null);

    const formData = new FormData();
    formData.append('file', file);

    try {
      const response = await fetch('http://localhost:8000/api/convert', {
        method: 'POST',
        body: formData,
      });

      if (!response.ok) {
        throw new Error('Conversion failed. Please try again.');
      }

      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      setPdfUrl(url);
    } catch (err) {
      console.error(err);
      setError(err.message || 'An unexpected error occurred.');
    } finally {
      setIsProcessing(false);
    }
  };

  const handlePreview = () => {
    if (pdfUrl) {
      window.open(pdfUrl, '_blank');
    }
  };

  const handleDownload = () => {
    if (pdfUrl) {
      const a = document.createElement('a');
      a.href = pdfUrl;
      a.download = 'converted_notes.pdf';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
    }
  };

  const formatFileSize = (bytes) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  return (
    <>
      <div className="bg-orb-1"></div>
      <div className="bg-orb-2"></div>
      
      <div className="app-container">
        <div className="glass-card">
          <div className="header">
            <h1>Neural Note Gen</h1>
            <p>Extract unique frames from videos and compile them into a PDF</p>
          </div>

          {error && (
            <div className="error-message">
              <AlertCircle size={20} />
              <span>{error}</span>
            </div>
          )}

          {!file && !isProcessing && !pdfUrl && (
            <div 
              className={`upload-area animate-in delay-1 ${isDragging ? 'drag-active' : ''}`}
              onDragOver={handleDragOver}
              onDragLeave={handleDragLeave}
              onDrop={handleDrop}
              onClick={() => fileInputRef.current?.click()}
            >
              <input 
                type="file" 
                ref={fileInputRef} 
                onChange={handleFileChange} 
                accept="video/*" 
                style={{ display: 'none' }} 
              />
              <div className="upload-content">
                <div className="upload-icon">
                  <UploadCloud size={32} />
                </div>
                <div className="upload-text">Click to upload or drag and drop</div>
                <div className="upload-subtext">MP4, WebM, or Ogg (max 100MB)</div>
              </div>
            </div>
          )}

          {file && !isProcessing && !pdfUrl && (
            <div className="animate-in delay-1" style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
              <div className="file-info">
                <div className="file-icon-container">
                  <FileVideo size={28} color="var(--accent-1)" />
                </div>
                <div className="file-details">
                  <div className="file-name" title={file.name}>{file.name}</div>
                  <div className="file-size">{formatFileSize(file.size)}</div>
                </div>
                <button className="remove-btn" onClick={clearFile}>
                  <X size={20} />
                </button>
              </div>
              
              <button className="btn-primary" onClick={handleConvert}>
                Convert to PDF
              </button>
            </div>
          )}

          {isProcessing && (
            <div className="progress-container animate-in delay-1">
              <div className="pulse-ring">
                <div className="pulse-core"></div>
              </div>
              <div className="status-text">
                <h3>Processing Video</h3>
                <p style={{ marginTop: '0.5rem' }}>
                  Extracting frames and generating PDF...
                </p>
              </div>
            </div>
          )}

          {pdfUrl && (
            <div className="success-container animate-in delay-1">
              <div className="success-icon-wrap">
                <CheckCircle className="success-icon" />
              </div>
              <div className="status-text">
                <h3>Conversion Complete!</h3>
                <p style={{ marginTop: '0.5rem' }}>
                  Your document is ready for preview and download.
                </p>
              </div>
              
              <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem', width: '100%', marginTop: '1.5rem' }}>
                <div style={{ display: 'flex', gap: '1rem', width: '100%' }}>
                  <button 
                    className="btn-primary" 
                    onClick={handlePreview}
                    style={{ flex: 1 }}
                  >
                    <Eye size={20} />
                    Preview PDF
                  </button>
                  <button 
                    className="btn-primary" 
                    onClick={handleDownload}
                    style={{ flex: 1 }}
                  >
                    <Download size={20} />
                    Download
                  </button>
                </div>
                
                <button 
                  className="btn-primary secondary-action" 
                  onClick={clearFile}
                  style={{ width: '100%' }}
                >
                  Convert Another Video
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </>
  );
}

export default App;
