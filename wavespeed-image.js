#!/usr/bin/env node
/**
 * WaveSpeed Image Analysis Tool
 * User-Requested Only — kostenpflichtig ($0.14/Bild)
 */

const fs = require('fs');
const path = require('path');

// Config
const API_BASE = 'https://api.wavespeed.ai/v1';
const MAX_IMAGES = 7;
const PRICE_PER_IMAGE = 0.14;

// Load token from env
const BANANA_TOKEN = process.env.BANANA_TOKEN;

function showUsage() {
  console.log(`
Usage: wavespeed-image <command> [options]

Commands:
  analyze <image...>    Analyze one or more images

Options:
  --prompt <text>       Analysis prompt (required)
  --dry-run             Show cost without executing
  -h, --help            Show this help

Examples:
  wavespeed-image analyze photo.jpg --prompt "What's in this image?"
  wavespeed-image analyze img1.jpg img2.jpg --prompt "Compare these"
`);
}

function showCostWarning(imageCount) {
  const totalCost = (imageCount * PRICE_PER_IMAGE).toFixed(2);
  console.log(`
╔════════════════════════════════════════════════════════════╗
║  ⚠️  KOSTENHINWEIS — WaveSpeed Image Analysis              ║
╠════════════════════════════════════════════════════════════╣
║  Anzahl Bilder: ${String(imageCount).padEnd(44)}║
║  Preis pro Bild: $${String(PRICE_PER_IMAGE).padEnd(43)}║
║  Gesamtkosten: ~$${totalCost.padEnd(44)}║
╠════════════════════════════════════════════════════════════╣
║  Abrechnung über dein WaveSpeed Guthaben                   ║
║  https://wavespeed.ai/account/billing                      ║
╚════════════════════════════════════════════════════════════╝
`);
}

async function confirmExecution() {
  // In OpenClaw context, this would be handled by the system
  // For CLI: require explicit --confirm flag
  return process.argv.includes('--confirm');
}

async function analyzeImages(imagePaths, prompt) {
  console.log(`\n🖼️  Analysiere ${imagePaths.length} Bilder...`);
  console.log(`📝 Prompt: "${prompt}"`);
  console.log(`\n⏳ Anfrage wird gesendet...\n`);
  
  // TODO: Implement actual API call
  // For now, return simulated response
  return {
    success: true,
    results: imagePaths.map(img => ({
      file: path.basename(img),
      analysis: `[Analyse-Ergebnis für ${path.basename(img)} würde hier stehen]`
    }))
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
    console.error('❌ Fehler: BANANA_TOKEN nicht gesetzt in ~/.config/openclaw/env');
    process.exit(1);
  }
  
  const command = args[0];
  
  if (command === 'analyze') {
    // Parse arguments
    const imagePaths = [];
    let prompt = '';
    let i = 1;
    
    while (i < args.length) {
      if (args[i] === '--prompt') {
        prompt = args[++i] || '';
      } else if (args[i] === '--dry-run') {
        // Skip
      } else if (args[i] === '--confirm') {
        // Skip
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
      console.error(`❌ Fehler: Maximum ${MAX_IMAGES} Bilder erlaubt`);
      process.exit(1);
    }
    
    if (!prompt) {
      console.error('❌ Fehler: --prompt erforderlich');
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
    if (!await confirmExecution()) {
      console.log('\n⚠️  Hinweis: Füge --confirm hinzu um die Anfrage auszuführen');
      console.log(`   Befehl: wavespeed-image analyze ${imagePaths.join(' ')} --prompt "${prompt}" --confirm\n`);
      process.exit(0);
    }
    
    // Execute
    const result = await analyzeImages(imagePaths, prompt);
    
    if (result.success) {
      console.log('✅ Analyse abgeschlossen\n');
      for (const r of result.results) {
        console.log(`📄 ${r.file}:`);
        console.log(`   ${r.analysis}\n`);
      }
    }
    
  } else {
    console.error(`❌ Unbekannter Befehl: ${command}`);
    showUsage();
    process.exit(1);
  }
}

main().catch(err => {
  console.error('❌ Fehler:', err.message);
  process.exit(1);
});
