#!/usr/bin/env node
// process-pond-textures.py — portiert nach javascript
// Quelle: python, Onboarding@main:scripts/process-pond-textures.py
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

/**
 * Chroma-key pond textures to add a clean alpha channel.
 *
 * The leaf/blossom source webps ship on solid backgrounds (dark green or white)
 * rather than transparency, so `alphaTest` clipping in three.js has nothin to
 * key on. This produces RGBA PNGs with a soft alpha mask so the R3F planes clip
 * to the real silhouette.
 */

const fs = require('fs');
const path = require('path');
const { createCanvas, loadImage, Image } = require('canvas');

const BASE = "public/media/pond";
const OUT = "public/media/pond/processed";

// Ensure output directory exists
if (!fs.existsSync(OUT)) {
    fs.mkdirSync(OUT, { recursive: true });
}

function getArrayFromImageData(imageData) {
    const data = imageData.data;
    const width = imageData.width;
    const height = imageData.height;
    const r = new Array(width * height);
    const g = new Array(width * height);
    const b = new Array(width * height);

    for (let i = 0; i < data.length; i += 4) {
        const idx = Math.floor(i / 4);
        r[idx] = data[i];
        g[idx] = data[i + 1];
        b[idx] = data[i + 2];
    }

    return [r, g, b, width, height];
}

function key_out(filePath, outputPath, mode, feather = 2.0) {
    loadImage(filePath).then(img => {
        const canvas = createCanvas(img.width, img.height);
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0);

        const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        const [r, g, b, width, height] = getArrayFromImageData(imageData);
        const alpha = new Uint8ClampedArray(width * height);

        if (mode === "green") {
            // Dark-green background: low overall brightness AND green-dominant-but-dark.
            // Foreground leaf is much brighter / lighter green.
            for (let i = 0; i < r.length; i++) {
                const lum = (r[i] + g[i] + b[i]) / 3.0;
                // background pixels: very dark (lum < ~35) — the bg is ~(3,50,0)=17
                const bg = lum < 40.0;
                alpha[i] = bg ? 0 : 255;
            }
        } else if (mode === "white") {
            // White background: near-white, low saturation.
            for (let i = 0; i < r.length; i++) {
                const mn = Math.min(r[i], g[i], b[i]);
                const mx = Math.max(r[i], g[i], b[i]);
                // background: bright and low chroma
                const white = (mn > 218.0) && ((mx - mn) < 28.0);
                alpha[i] = white ? 0 : 255;
            }
        } else {
            throw new Error(mode);
        }

        // Apply Gaussian blur to alpha channel using a second canvas
        const alphaCanvas = createCanvas(width, height);
        const alphaCtx = alphaCanvas.getContext('2d');
        const alphaImgData = alphaCtx.createImageData(width, height);

        for (let i = 0; i < alpha.length; i++) {
            alphaImgData.data[i * 4] = 0;       // R
            alphaImgData.data[i * 4 + 1] = 0;   // G
            alphaImgData.data[i * 4 + 2] = 0;   // B
            alphaImgData.data[i * 4 + 3] = alpha[i]; // A
        }

        alphaCtx.putImageData(alphaImgData, 0, 0);

        // Create a new canvas for blurred result
        const blurCanvas = createCanvas(width, height);
        const blurCtx = blurCanvas.getContext('2d');
        blurCtx.filter = `blur(${feather}px)`;
        blurCtx.drawImage(alphaCanvas, 0, 0);
        blurCtx.filter = 'none';

        // Get blurred image data
        const blurredImageData = blurCtx.getImageData(0, 0, width, height);
        const blurredAlpha = [];
        for (let i = 0; i < blurredImageData.data.length; i += 4) {
            blurredAlpha.push(blurredImageData.data[i + 3]);
        }

        // Put original image onto a new canvas with new alpha
        const finalCanvas = createCanvas(width, height);
        const finalCtx = finalCanvas.getContext('2d');
        finalCtx.drawImage(img, 0, 0);
        const finalImageData = finalCtx.getImageData(0, 0, width, height);

        for (let i = 0; i < finalImageData.data.length; i += 4) {
            const idx = i / 4;
            finalImageData.data[i + 3] = blurredAlpha[idx];
        }

        finalCtx.putImageData(finalImageData, 0, 0);

        // Crop to content bounds
        let minX = width, minY = height, maxX = 0, maxY = 0;
        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                const idx = (y * width + x) * 4 + 3;
                if (finalImageData.data[idx] > 0) {
                    minX = Math.min(minX, x);
                    minY = Math.min(minY, y);
                    maxX = Math.max(maxX, x);
                    maxY = Math.max(maxY, y);
                }
            }
        }

        if (minX <= maxX && minY <= maxY) {
            const cropWidth = maxX - minX + 1;
            const cropHeight = maxY - minY + 1;
            const croppedCanvas = createCanvas(cropWidth, cropHeight);
            const croppedCtx = croppedCanvas.getContext('2d');
            croppedCtx.drawImage(finalCanvas, -minX, -minY);
            const buffer = croppedCanvas.toBuffer('image/png');
            fs.writeFileSync(outputPath, buffer);
        } else {
            const buffer = finalCanvas.toBuffer('image/png');
            fs.writeFileSync(outputPath, buffer);
        }

        console.log(`${path.basename(filePath)} -> ${path.basename(outputPath)} (${mode})`);
    }).catch(err => {
        console.error(`Error processing ${filePath}:`, err);
    });
}

// Lily pads
key_out(`${BASE}/blaetter/12130585.webp`, `${OUT}/leaf-a.png`, "green");
key_out(`${BASE}/blaetter/48178242.webp`, `${OUT}/leaf-b.png`, "white");

// Blossoms with white backgrounds -> clean cutouts (only these two key cleanly)
key_out(`${BASE}/blueten/78370994.webp`, `${OUT}/blossom-a.png`, "white", 3.0);
key_out(`${BASE}/blueten/70017289.webp`, `${OUT}/blossom-b.png`, "white", 3.0);

console.log("done");
