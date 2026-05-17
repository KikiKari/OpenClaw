const { exec, spawn } = require('child_process');
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

class TikTokRecorder {
  constructor(username) {
    this.username = username;
    this.currentStreamUrl = null;
    this.ffmpegProcess = null;
    this.browser = null;
    this.page = null;
    this.isRecording = false;
    this.outputFile = `tiktok_${username}_${Date.now()}.flv`;
  }

  async init() {
    console.log(`[${new Date().toLocaleTimeString()}] Initialisiere Recorder für @${this.username}...`);
    this.browser = await chromium.launch({ headless: true });
    this.page = await this.browser.newPage();
    
    // Netzwerk-Monitoring
    this.page.on('request', request => {
      const url = request.url();
      if (url.includes('.flv') && url.includes('tiktokcdn')) {
        console.log(`[${new Date().toLocaleTimeString()}] Neuer FLV-Link gefunden`);
        this.currentStreamUrl = url;
        this.restartFFmpeg();
      }
    });
    
    await this.page.goto(`https://www.tiktok.com/@${this.username}/live`);
    await this.page.waitForTimeout(5000);
    
    // Consent akzeptieren
    const consent = await this.page.$('button:has-text("Verstanden"), button:has-text("Accept")');
    if (consent) await consent.click().catch(() => {});
    
    console.log(`[${new Date().toLocaleTimeString()}] Recorder bereit`);
  }

  restartFFmpeg() {
    if (!this.currentStreamUrl) return;
    
    // Alten FFmpeg-Prozess beenden
    if (this.ffmpegProcess) {
      console.log(`[${new Date().toLocaleTimeString()}] Beende alten FFmpeg-Prozess...`);
      this.ffmpegProcess.kill('SIGTERM');
    }
    
    // Neuen FFmpeg-Prozess starten
    console.log(`[${new Date().toLocaleTimeString()}] Starte FFmpeg mit neuem Link...`);
    this.ffmpegProcess = spawn('ffmpeg', [
      '-i', this.currentStreamUrl,
      '-c', 'copy',
      '-f', 'flv',
      '-y',
      this.outputFile
    ], {
      stdio: ['ignore', 'pipe', 'pipe']
    });
    
    this.ffmpegProcess.stderr.on('data', (data) => {
      // FFmpeg-Output filtern (nur Fehler)
      const output = data.toString();
      if (output.includes('error') || output.includes('Error')) {
        console.error(`[FFmpeg] ${output.trim()}`);
      }
    });
    
    this.isRecording = true;
    console.log(`[${new Date().toLocaleTimeString()}] Aufnahme gestartet: ${this.outputFile}`);
  }

  async keepAlive() {
    // Alle 30 Sekunden Seite neu laden für frischen Link
    setInterval(async () => {
      if (this.page && !this.page.isClosed()) {
        console.log(`[${new Date().toLocaleTimeString()}] Keepalive: Lade Seite neu...`);
        await this.page.reload({ waitUntil: 'networkidle' });
        await this.page.waitForTimeout(3000);
      }
    }, 30000);
  }

  async stop() {
    console.log(`[${new Date().toLocaleTimeString()}] BeRecorder...`);
    if (this.ffmpegProcess) {
      this.ffmpegProcess.kill('SIGTERM');
    }
    if (this.browser) {
      await this.browser.close();
    }
    console.log(`[${new Date().toLocaleTimeString()}] Aufnahme gespeichert: ${this.outputFile}`);
  }
}

// Hauptfunktion
async function main() {
  const username = process.argv[2] || 'iman.hayatiii';
  const duration = parseInt(process.argv[3]) || 60; // Minuten
  
  const recorder = new TikTokRecorder(username);
  await recorder.init();
  recorder.keepAlive();
  
  console.log(`\n[${new Date().toLocaleTimeString()}] Starte Daueraufzeichnung für ${duration} Minuten...`);
  console.log(`Datei: ${recorder.outputFile}\n`);
  
  // Nach gewünschter Dauer stoppen
  setTimeout(() => {
    recorder.stop();
    process.exit(0);
  }, duration * 60 * 1000);
  
  // Graceful Shutdown
  process.on('SIGINT', () => {
    console.log('\nSIGINT empfangen, beende...');
    recorder.stop();
  });
}

main().catch(console.error);
