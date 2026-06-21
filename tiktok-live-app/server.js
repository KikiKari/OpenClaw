// @deprecated Legacy HTTP wrapper. Canonical status and URL resolution
// live under workspace/skills/tiktok-live*/; see TIKTOK-CURRENT.md.
const express = require('express');
const { spawn } = require('child_process');
const path = require('path');

const app = express();
const PORT = 5001;

// Endpoint: /tiktok/status/:user?quality=sd|ld|hd
app.get('/tiktok/status/:user', (req, res) => {
  const user = req.params.user;
  const quality = req.query.q || 'sd'; // default quality

  // Build path to the existing Playwright script
  const scriptPath = path.join(__dirname, 'get-stream.js');

  // Spawn the script; it will output the best stream URL on stdout
  const child = spawn('node', [scriptPath, user, quality]);

  let stdout = '';
  let stderr = '';

  child.stdout.on('data', (data) => {
    stdout += data.toString();
  });

  child.stderr.on('data', (data) => {
    stderr += data.toString();
  });

  child.on('close', (code) => {
    if (code === 0) {
      const url = stdout.trim();
      if (url) {
        res.json({ success: true, username: user, vlc_links: [url] });
      } else {
        res.status(500).json({ success: false, error: 'No stream URL captured' });
      }
    } else {
      res.status(500).json({ success: false, error: stderr.trim() || 'Script error' });
    }
  });
});

app.listen(PORT, () => {
  console.log(`TikTok monitor API listening on port ${PORT}`);
});
