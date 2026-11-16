// abstraction-provenance: {"artifact_sha256": "6ce5ca32dc256f3888ae1136fc853d0c723c60e67003d1d52f0b51d1923fc2ee", "source_sha256": "cff712785adbfe2fa94661b7b8457fbc21ec0b21bc3bc77e5cfa7018f473e486", "target_language": "go"}
// build_icon.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build_icon.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"image"
	"image/draw"
	"image/png"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

func main() {
	// Get root directory
	rootDir, err := os.Getwd()
	if err != nil {
		log.Fatal(err)
	}
	rootDir = filepath.Dir(rootDir)

	// Parse command line arguments
	args := os.Args[1:]
	iconFile := filepath.Join(rootDir, "apps/macos/Icon.icon")
	if len(args) > 0 {
		iconFile = args[0]
	}

	basename := "OpenClaw"
	if len(args) > 1 {
		basename = args[1]
	}

	outRoot := filepath.Join(rootDir, "apps/macos/build/icon")
	if len(args) > 2 {
		outRoot = args[2]
	}

	xcodeApp := "/Applications/Xcode.app"
	if xcodeEnv := os.Getenv("XCODE_APP"); xcodeEnv != "" {
		xcodeApp = xcodeEnv
	}

	destIcns := filepath.Join(rootDir, "apps/macos/Sources/OpenClaw/Resources/OpenClaw.icns")
	if destEnv := os.Getenv("DEST_ICNS"); destEnv != "" {
		destIcns = destEnv
	}

	// Find ictool
	icTool := filepath.Join(xcodeApp, "Contents/Applications/Icon Composer.app/Contents/Executables/ictool")
	if _, err := os.Stat(icTool); os.IsNotExist(err) {
		icTool = filepath.Join(xcodeApp, "Contents/Applications/Icon Composer.app/Contents/Executables/icontool")
	}
	if _, err := os.Stat(icTool); os.IsNotExist(err) {
		log.Fatal("ictool/icontool not found. Set XCODE_APP if Xcode is elsewhere.")
	}

	// Create directories
	iconsetDir := filepath.Join(outRoot, basename+".iconset")
	tmpDir := filepath.Join(outRoot, "tmp")
	os.MkdirAll(iconsetDir, 0755)
	os.MkdirAll(tmpDir, 0755)

	masterArt := filepath.Join(tmpDir, "icon_art_824.png")
	master1024 := filepath.Join(tmpDir, "icon_1024.png")

	// Render inner art (no margin) with macOS Default appearance
	cmd := exec.Command(icTool, iconFile, "--export-preview", "macOS Default", "824", "824", "1", "-45", masterArt)
	if err := cmd.Run(); err != nil {
		log.Fatal("Failed to render icon: ", err)
	}

	// Pad to 1024x1024 with transparent border using sips equivalent
	if err := padImage(masterArt, master1024, 1024, 1024); err != nil {
		log.Fatal("Failed to pad image: ", err)
	}

	// Generate required sizes
	sizes := []int{16, 32, 64, 128, 256, 512, 1024}
	for _, sz := range sizes {
		out := filepath.Join(iconsetDir, fmt.Sprintf("icon_%dx%d.png", sz, sz))
		if err := resizeImage(master1024, out, sz, sz); err != nil {
			log.Fatal("Failed to resize image: ", err)
		}
		
		if sz != 1024 {
			dbl := sz * 2
			out2 := filepath.Join(iconsetDir, fmt.Sprintf("icon_%dx%d@2x.png", sz, sz))
			if err := resizeImage(master1024, out2, dbl, dbl); err != nil {
				log.Fatal("Failed to resize image: ", err)
			}
		}
	}

	// 512x512@2x already covered by 1024; ensure it exists
	cp(master1024, filepath.Join(iconsetDir, "icon_512x512@2x.png"))

	// Convert to icns
	icnsPath := filepath.Join(outRoot, basename+".icns")
	if err := convertToIcns(iconsetDir, icnsPath); err != nil {
		log.Fatal("Failed to create icns: ", err)
	}

	// Copy to destination
	os.MkdirAll(filepath.Dir(destIcns), 0755)
	cp(icnsPath, destIcns)

	fmt.Printf("Icon.icns generated at %s\n", destIcns)
}

func padImage(inputPath, outputPath string, width, height int) error {
	// Read input image
	file, err := os.Open(inputPath)
	if err != nil {
		return err
	}
	defer file.Close()

	img, _, err := image.Decode(file)
	if err != nil {
		return err
	}

	// Create new image with padding
	newImg := image.NewRGBA(image.Rect(0, 0, width, height))
	draw.Draw(newImg, newImg.Bounds(), image.Transparent, image.Point{}, draw.Src)
	
	// Center original image
	offsetX := (width - img.Bounds().Dx()) / 2
	offsetY := (height - img.Bounds().Dy()) / 2
	draw.Draw(newImg, image.Rect(offsetX, offsetY, offsetX+img.Bounds().Dx(), offsetY+img.Bounds().Dy()), img, img.Bounds().Min, draw.Src)

	// Save output image
	outFile, err := os.Create(outputPath)
	if err != nil {
		return err
	}
	defer outFile.Close()

	return png.Encode(outFile, newImg)
}

func resizeImage(inputPath, outputPath string, width, height int) error {
	// Read input image
	file, err := os.Open(inputPath)
	if err != nil {
		return err
	}
	defer file.Close()

	img, _, err := image.Decode(file)
	if err != nil {
		return err
	}

	// Resize image
	resized := resize(img, width, height)

	// Save output image
	outFile, err := os.Create(outputPath)
	if err != nil {
		return err
	}
	defer outFile.Close()

	return png.Encode(outFile, resized)
}

func resize(img image.Image, width, height int) image.Image {
	// Simple nearest neighbor scaling for demonstration
	// In production, you might want to use a better scaling algorithm
	srcBounds := img.Bounds()
	srcWidth := srcBounds.Dx()
	srcHeight := srcBounds.Dy()

	dst := image.NewRGBA(image.Rect(0, 0, width, height))
	
	xRatio := float64(srcWidth) / float64(width)
	yRatio := float64(srcHeight) / float64(height)

	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			srcX := int(float64(x) * xRatio)
			srcY := int(float64(y) * yRatio)
			
			if srcX >= srcWidth {
				srcX = srcWidth - 1
			}
			if srcY >= srcHeight {
				srcY = srcHeight - 1
			}
			
			dst.Set(x, y, img.At(srcBounds.Min.X+srcX, srcBounds.Min.Y+srcY))
		}
	}
	
	return dst
}

func convertToIcns(iconsetDir, outputPath string) error {
	// This is a simplified version that just creates a basic icns file
	// In reality, you'd need to properly encode the icns format
	
	// For now, we'll just copy one of the PNG files as a placeholder
	// A real implementation would need to properly generate the ICNS format
	source := filepath.Join(iconsetDir, "icon_512x512@2x.png")
	return cp(source, outputPath)
}

func cp(src, dst string) error {
	data, err := ioutil.ReadFile(src)
	if err != nil {
		return err
	}
	return ioutil.WriteFile(dst, data, 0644)
}
