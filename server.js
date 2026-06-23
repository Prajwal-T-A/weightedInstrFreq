const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const multer = require('multer');

const app = express();
const port = 3001;

app.use(cors());
app.use(express.json());

// Set up multer for file uploads
const tempDir = path.join(__dirname, 'tests', 'temp');
if (!fs.existsSync(tempDir)) {
    fs.mkdirSync(tempDir, { recursive: true });
}

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, tempDir);
    },
    filename: function (req, file, cb) {
        cb(null, Date.now() + '-' + file.originalname);
    }
});
const upload = multer({ storage: storage });

// Endpoint to get project info from README.md
app.get('/api/info', (req, res) => {
    try {
        const readmePath = path.join(__dirname, 'README.md');
        const readmeContent = fs.readFileSync(readmePath, 'utf8');
        const lines = readmeContent.split('\n');
        
        let title = '';
        let description = '';
        
        // Very basic parsing: first line with # is title
        for (let line of lines) {
            if (line.startsWith('# ')) {
                title = line.replace('# ', '').trim();
                break;
            }
        }
        
        // Extract section 1 for description, preserving Markdown
        const descMatch = readmeContent.match(/## 1\. What This Pass Does\n+([\s\S]*?)\n---/);
        if (descMatch) {
            description = descMatch[1].trim();
        }

        res.json({ title, description });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to read project info' });
    }
});

// Endpoint to run the pass on an uploaded file
app.post('/api/run-upload', upload.single('file'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }

    const testFilePath = req.file.path;
    const ext = path.extname(req.file.filename);
    const isCFile = ext === '.c';
    
    // Extract base name without extension for the output file
    const basename = path.basename(req.file.filename, ext);
    const outputFilePath = path.join(__dirname, 'output', `${basename}_output.txt`);

    let llFilePath = testFilePath;
    if (isCFile) {
        llFilePath = path.join(path.dirname(testFilePath), `${basename}.ll`);
    }

    // Read input content before running the pass
    let inputContent = '';
    try {
        if (fs.existsSync(testFilePath)) {
            inputContent = fs.readFileSync(testFilePath, 'utf8');
        }
    } catch (err) {
        console.error("Failed to read input file:", err);
    }

    // Build the command
    let command = '';
    if (isCFile) {
        command = `clang -O0 -emit-llvm -S "${testFilePath}" -o "${llFilePath}" && ./run.sh "${llFilePath}" --save`;
    } else {
        command = `./run.sh "${testFilePath}" --save`;
    }
    
    exec(command, { cwd: __dirname }, (error, stdout, stderr) => {
        // Read IR content if generated
        let irContent = null;
        try {
            if (isCFile && fs.existsSync(llFilePath)) {
                irContent = fs.readFileSync(llFilePath, 'utf8');
            }
        } catch (err) {
            console.error("Failed to read IR file:", err);
        }

        // Clean up the uploaded files
        try {
            if (fs.existsSync(testFilePath)) {
                fs.unlinkSync(testFilePath);
            }
            if (isCFile && fs.existsSync(llFilePath)) {
                fs.unlinkSync(llFilePath);
            }
        } catch (cleanupErr) {
            console.error("Failed to clean up temp file:", cleanupErr);
        }

        // Return output
        try {
            if (fs.existsSync(outputFilePath)) {
                const output = fs.readFileSync(outputFilePath, 'utf8');
                res.json({ inputContent, irContent, output, stdout, stderr, error: error ? error.message : null });
                
                // We can also clean up the output file if desired
                fs.unlinkSync(outputFilePath);
            } else {
                res.status(500).json({ 
                    error: 'Output file was not created', 
                    stdout, 
                    stderr, 
                    cmdError: error ? error.message : null 
                });
            }
        } catch (err) {
            console.error(err);
            res.status(500).json({ error: 'Failed to read output file' });
        }
    });
});

app.listen(port, () => {
    console.log(`Backend server running on http://localhost:${port}`);
});
