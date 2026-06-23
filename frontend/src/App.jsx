import React, { useState, useEffect, useRef } from 'react';
import { Play, FileCode2, Terminal, Loader2, AlertCircle, UploadCloud, Activity } from 'lucide-react';
import ReactMarkdown from 'react-markdown';
import './index.css';

function App() {
  const [projectInfo, setProjectInfo] = useState({ title: '', description: '' });
  const [selectedFile, setSelectedFile] = useState(null);
  const [inputContent, setInputContent] = useState(null);
  const [irContent, setIrContent] = useState(null);
  const [output, setOutput] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);
  const [infoLoading, setInfoLoading] = useState(true);
  
  const fileInputRef = useRef(null);

  useEffect(() => {
    const fetchInfo = async () => {
      try {
        const res = await fetch('/api/info');
        if (res.ok) {
          const info = await res.json();
          setProjectInfo(info);
        }
      } catch (err) {
        console.error("Failed to fetch project info", err);
        setError("Could not connect to backend server.");
      } finally {
        setInfoLoading(false);
      }
    };
    
    fetchInfo();
  }, []);

  const handleFileChange = (e) => {
    if (e.target.files && e.target.files.length > 0) {
      setSelectedFile(e.target.files[0]);
      // Reset views when a new file is uploaded
      setInputContent(null);
      setIrContent(null);
      setOutput(null);
      setError(null);
    }
  };

  const handleUploadClick = () => {
    if (fileInputRef.current) {
      fileInputRef.current.click();
    }
  };

  const handleRunPass = async () => {
    if (!selectedFile) return;
    
    setIsLoading(true);
    setError(null);
    
    const formData = new FormData();
    formData.append('file', selectedFile);

    try {
      const res = await fetch('/api/run-upload', {
        method: 'POST',
        body: formData,
      });
      
      const data = await res.json();
      
      if (!res.ok) {
        setError(data.error || "An error occurred while running the pass");
      } else {
        setInputContent(data.inputContent);
        setIrContent(data.irContent);
        setOutput(data.output);
      }
    } catch (err) {
      setError("Failed to communicate with backend server.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <>
      <nav className="navbar fade-in">
        <h1><Activity size={28} className="text-accent" /> {projectInfo.title || 'WeightedInstrFreq'}</h1>
      </nav>

      <div className="main-layout">
        {/* Sidebar */}
        <aside className="sidebar glass-card fade-in delay-1">
          {infoLoading ? (
            <div className="loading"><Loader2 className="spinner" /> Loading info...</div>
          ) : (
            <div className="markdown-content">
              <ReactMarkdown>
                {projectInfo.description || 'An LLVM FunctionPass that counts instructions...'}
              </ReactMarkdown>
            </div>
          )}

          <div className="action-section mt-4">
            <h2><FileCode2 className="accent-icon" /> Run Analysis</h2>
            
            {error && (
              <div className="error-text flex items-center gap-2">
                <AlertCircle size={18} /> {error}
              </div>
            )}
            
            <div className="controls">
              <input 
                type="file" 
                accept=".ll,.c" 
                ref={fileInputRef} 
                onChange={handleFileChange} 
                style={{ display: 'none' }}
              />
              
              <button 
                type="button" 
                className={`btn-upload ${selectedFile ? 'has-file' : ''}`}
                onClick={handleUploadClick}
                disabled={isLoading}
              >
                <UploadCloud size={18} /> 
                {selectedFile ? selectedFile.name : 'Select .ll or .c File'}
              </button>
              
              <button 
                onClick={handleRunPass} 
                disabled={isLoading || !selectedFile}
                className="btn-run"
              >
                {isLoading ? (
                  <><Loader2 size={18} className="spinner" /> Running...</>
                ) : (
                  <><Play size={18} /> Run Pass</>
                )}
              </button>
            </div>
          </div>
        </aside>

        {/* Results Panel */}
        <main className="results-panel fade-in delay-2">
          {/* Input File Display */}
          <div className="glass-card code-view">
            <h3><FileCode2 size={20} /> Input File (.ll / .c)</h3>
            <div className="code-container">
              {isLoading ? (
                <div className="loading"><Loader2 className="spinner" /> Preparing...</div>
              ) : inputContent ? (
                <pre className="input-code">{inputContent}</pre>
              ) : (
                <span className="text-muted" style={{color: 'var(--text-muted)'}}>Upload a test file and run the pass to view the input code here.</span>
              )}
            </div>
          </div>

          {/* IR File Display */}
          {irContent && (
            <div className="glass-card code-view">
              <h3><FileCode2 size={20} /> Generated IR (.ll)</h3>
              <div className="code-container">
                <pre className="input-code">{irContent}</pre>
              </div>
            </div>
          )}

          {/* Output Display */}
          <div className="glass-card code-view">
            <h3><Terminal size={20} /> Analysis Output</h3>
            <div className="code-container">
              {isLoading ? (
                <div className="loading"><Loader2 className="spinner" /> Analyzing instructions...</div>
              ) : output ? (
                <pre>{output}</pre>
              ) : (
                <span className="text-muted" style={{color: 'var(--text-muted)'}}>Upload a test file and run the pass to view the frequency report here.</span>
              )}
            </div>
          </div>
        </main>
      </div>
    </>
  );
}

export default App;
