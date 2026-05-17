#!/usr/bin/env node
/**
 * WaveSpeed Image Analysis Tool
 * User-Requested Only — kostenpflichtig ($0.07-0.14/Bild)
 * 
 * API: https://api.wavespeed.ai/api/v3/{model-id}
 * Model: google/nano-banana-2/edit
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const { URL } = require('url');

// Config
const API_BASE = 'api.wavespeed.ai';
const API_VERSION = 'v3';
const MODEL_ID = 'google/nano-banana-2/edit';
const MAX_IMAGES = 1; // Banana 2 unterstützt 1 Bild pro Request
const PRICE_PER_IMAGE = 0.07; // Aktueller Preis lt. Website

// Load token from env
const BANANA_TOKEN = process.env.BANANA_TOKEN;

function showUsage() {
  console.log(`
Usage: wavespeed-image <command> [options]

Commands:
  analyze <image>       Analyze an image with Gemini 3.1 Flash
  describe <image>      Generate image description
  edit <image>          Edit image based on prompt

Options:
  --prompt <text>       Analysis/editing prompt (required for analyze/edit)
  --output <path>       Output path for edited images
  --dry-run             Show cost without executing
  --confirm             Confirm execution (required)
  -h, --help            Show this help

Examples:
  # Image analysis
  wavespeed-image analyze photo.jpg --prompt "What's in this image?" --confirm
  
  # Image description
  wavespeed-image describe artwork.jpg --confirm
  
  # Image editing (generates new image)
  wavespeed-image edit portrait.jpg --prompt "Convert to oil painting style" --confirm

Cost: ~$${PRICE_PER_IMAGE} per image
`);
}

function showCostWarning(imageCount) {
  const totalCost = (imageCount * PRICE_PER_IMAGE).toFixed(2);
  console.log(`
╔════════════════════════════════════════════════════════════╗
║  ⚠️  KOSTENHINWEIS — WaveSpeed Image (Nano Banana 2)       ║
╠════════════════════════════════════════════════════════════╣
║  Modell: google/nano-banana-2/edit                         ║
║  Anzahl Bilder: ${String(imageCount).padEnd(44)}║
║  Preis pro Bild: $${String(PRICE_PER_IMAGE).padEnd(43)}║
║  Gesamtkosten: ~$${totalCost.padEnd(44)}║
╠════════════════════════════════════════════════════════════╣
║  Abrechnung über dein WaveSpeed Guthaben                   ║
║  https://wavespeed.ai/account                              ║
╚════════════════════════════════════════════════════════════╝
`);
}

// API Helper Functions
function makeRequest(method, path, data = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: API_BASE,
      port: 443,
      path: `/api/${API_VERSION}${path}`,
      method: method,
      headers: {
        'Authorization': `Bearer ${BANANA_TOKEN}`,
        'Content-Type': 'application/json',
        ...headers
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(body);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(json);
          } else {
            reject(new Error(`API Error ${res.statusCode}: ${json.message || body}`));
          }
        } catch (e) {
          reject(new Error(`Invalid JSON: ${body}`));
        }
      });
    });

    req.on('error', reject);
    
    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

async function submitTask(modelId, params) {
  return makeRequest('POST', `/${modelId}`, params);
}

async function getResult(taskId) {
  return makeRequest('GET', `/predictions/${taskId}`);
}

async function pollForResult(taskId, maxAttempts = 60, interval = 2000) {
  console.log(`⏳ Warte auf Ergebnis (Task: ${taskId})...`);
  
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const result = await getResult(taskId);
    
    if (result.data) {
      const status = result.data.status;
      
      if (status === 'succeeded') {
        return result.data;
      } else if (status === 'failed') {
        throw new Error(`Task failed: ${result.data.error || 'Unknown error'}`);
      } else if (status === 'canceled') {
        throw new Error('Task was canceled');
      }
      
      // Still processing
      process.stdout.write(`\r   Status: ${status} (${attempt}/${maxAttempts})...`);
    }
    
    await new Promise(r => setTimeout(r, interval));
  }
  
  throw new Error('Timeout waiting for result');
}

function imageToBase64(imagePath) {
  const data = fs.readFileSync(imagePath);
  return data.toString('base64');
}

async function analyzeImage(imagePath, prompt) {
  console.log(`\n🖼️  Analysiere Bild: ${path.basename(imagePath)}`);
  console.log(`📝 Prompt: "${prompt}"`);
  
  // For analysis, we use the image and ask for description in output
  const base64Image = imageToBase64(imagePath);
  
  const params = {
    prompt: prompt || "Describe this image in detail",
    images: [base64Image],
    output_format: 'base64' // Get result as base64
  };
  
  console.log(`\n📤 Sende Anfrage an WaveSpeed API...`);
  const submitResponse = await submitTask(MODEL_ID, params);
  
  if (!submitResponse.data || !submitResponse.data.id) {
    throw new Error('Invalid API response: ' + JSON.stringify(submitResponse));
  }
  
  const taskId = submitResponse.data.id;
  const result = await pollForResult(taskId);
  
  return {
    success: true,
    taskId: taskId,
    output: result.output,
    outputUrl: result.output_url,
    createdAt: result.created_at,
    completedAt: result.completed_at
  };
}

async function describeImage(imagePath) {
  return analyzeImage(imagePath, "Describe this image in detail. What objects, people, colors, and scene elements are visible?");
}

async function editImage(imagePath, prompt, outputPath) {
  console.log(`\n🎨 Bearbeite Bild: ${path.basename(imagePath)}`);
  console.log(`📝 Prompt: "${prompt}"`);
  
  const base64Image = imageToBase64(imagePath);
  
  const params = {
    prompt: prompt,
    images: [base64Image],
    output_format: 'base64'
  };
  
  console.log(`\n📤 Sende Anfrage an WaveSpeed API...`);
  const submitResponse = await submitTask(MODEL_ID, params);
  const taskId = submitResponse.data.id;
  const result = await pollForResult(taskId);
  
  // Save output if path specified
  if (outputPath && result.output) {
    const outputData = Buffer.from(result.output, 'base64');
    fs.writeFileSync(outputPath, outputData);
    console.log(`\n💾 Gespeichert: ${outputPath}`);
  }
  
  return {
    success: true,
    taskId: taskId,
    outputUrl: result.output_url,
    savedTo: outputPath || null
  };
}

async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args.includes('-h') || args.includes('--help')) {
    showUsage();
    process.exit(0);
  }
  
  // Check auth
  if (!BANANA_TOKEN) {
    console.error('❌ Fehler: BANANA_TOKEN nicht gesetzt');
    console.error('   Füge hinzu zu: ~/.config/openclaw/env');
    console.error('   Format: BANANA_TOKEN="dein-token"');
    process.exit(1);
  }
  
  const command = args[0];
  
  // Parse arguments
  const imagePaths = [];
  let prompt = '';
  let outputPath = '';
  let i = 1;
  
  while (i < args.length) {
    if (args[i] === '--prompt') {
      prompt = args[++i] || '';
    } else if (args[i] === '--output') {
      outputPath = args[++i] || '';
    } else if (args[i] === '--confirm') {
      // Flag wird unten geprüft
    } else if (args[i] === '--dry-run') {
      // Flag wird unten geprüft
    } else if (!args[i].startsWith('--')) {
      imagePaths.push(args[i]);
    }
    i++;
  }
  
  // Validate
  if (imagePaths.length === 0) {
    console.error('❌ Fehler: Mindestens ein Bild-Pfad erforderlich');
    process.exit(1);
  }
  
  if (imagePaths.length > MAX_IMAGES) {
    console.error(`❌ Fehler: Maximum ${MAX_IMAGES} Bild(er) erlaubt`);
    process.exit(1);
  }
  
  // Validate files exist
  for (const img of imagePaths) {
    if (!fs.existsSync(img)) {
      console.error(`❌ Fehler: Datei nicht gefunden: ${img}`);
      process.exit(1);
    }
  }
  
  // Show cost warning
  showCostWarning(imagePaths.length);
  
  // Dry run
  if (args.includes('--dry-run')) {
    console.log('✅ Dry-run: Keine API-Anfrage gesendet\n');
    process.exit(0);
  }
  
  // Check for confirmation
  if (!args.includes('--confirm')) {
    console.log('\n⚠️  Hinweis: Füge --confirm hinzu um die Anfrage auszuführen');
    console.log(`   Befehl: wavespeed-image ${command} ${imagePaths.join(' ')}${prompt ? ` --prompt "${prompt}"` : ''} --confirm\n`);
    process.exit(0);
  }
  
  // Execute command
  try {
    let result;
    
    switch (command) {
      case 'analyze':
        if (!prompt) {
          console.error('❌ Fehler: --prompt erforderlich für analyze');
          process.exit(1);
        }
        result = await analyzeImage(imagePaths[0], prompt);
        console.log('\n✅ Analyse abgeschlossen\n');
        console.log('📊 Ergebnis:');
        console.log(`   Task ID: ${result.taskId}`);
        if (result.outputUrl) {
          console.log(`   URL: ${result.outputUrl}`);
        }
        break;
        
      case 'describe':
        result = await describeImage(imagePaths[0]);
        console.log('\n✅ Beschreibung erstellt\n');
        console.log('📊 Ergebnis:');
        console.log(`   Task ID: ${result.taskId}`);
        if (result.outputUrl) {
          console.log(`   URL: ${result.outputUrl}`);
        }
        break;
        
      case 'edit':
        if (!prompt) {
          console.error('❌ Fehler: --prompt erforderlich für edit');
          process.exit(1);
        }
        result = await editImage(imagePaths[0], prompt, outputPath);
        console.log('\n✅ Bearbeitung abgeschlossen\n');
        console.log('📊 Ergebnis:');
        console.log(`   Task ID: ${result.taskId}`);
        console.log(`   URL: ${result.outputUrl}`);
        if (result.savedTo) {
          console.log(`   Gespeichert: ${result.savedTo}`);
        }
        break;
        
      default:
        console.error(`❌ Unbekannter Befehl: ${command}`);
        showUsage();
        process.exit(1);
    }
    
  } catch (err) {
    console.error(`\n❌ Fehler: ${err.message}`);
    if (err.message.includes('401')) {
      console.error('   → Überprüfe dein BANANA_TOKEN');
    } else if (err.message.includes('429')) {
      console.error('   → Rate limit erreicht. Bitte warte einen Moment.');
    }
    process.exit(1);
  }
}

main().catch(err => {
  console.error('\n❌ Unerwarteter Fehler:', err.message);
  process.exit(1);
});
