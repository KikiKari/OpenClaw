#!/usr/bin/env pwsh
# index.html — portiert nach powershell
# Quelle: html, Projects@TikTok-Live-Companion:site/index.html
# auch in: Projects@TikTok-Live-Companion-Android:site/index.html
# auch in: Projects@TikTok-Live-Companion-iOS:site/index.html
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
    Generates an HTML file for TikTok LIVE Companion documentation.
.DESCRIPTION
    This script creates an HTML document with metadata and structure matching the original index.html,
    and writes it to a specified output file.
.PARAMETER OutputPath
    The path where the generated HTML file will be saved.
.EXAMPLE
    .\Generate-HtmlDocument.ps1 -OutputPath "C:\temp\index.html"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

# Create HTML content as XmlDocument for structured generation
$html = New-Object System.Xml.XmlDocument

# Create doctype (simulated as comment since PowerShell XML doesn't support DOCTYPE directly)
$comment = $html.CreateComment("!doctype html")
$html.AppendChild($comment) | Out-Null

# Create root html element with language attribute
$htmlElement = $html.CreateElement("html")
$htmlElement.SetAttribute("lang", "de")
$html.AppendChild($htmlElement) | Out-Null

# Create head section
$head = $html.CreateElement("head")
$htmlElement.AppendChild($head) | Out-Null

# Add meta tags
$metaCharset = $html.CreateElement("meta")
$metaCharset.SetAttribute("charset", "UTF-8")
$head.AppendChild($metaCharset) | Out-Null

$metaViewport = $html.CreateElement("meta")
$metaViewport.SetAttribute("name", "viewport")
$metaViewport.SetAttribute("content", "width=device-width, initial-scale=1.0")
$head.AppendChild($metaViewport) | Out-Null

$metaDescription = $html.CreateElement("meta")
$metaDescription.SetAttribute("name", "description")
$metaDescription.SetAttribute("content", "Dokumentation für TikTok LIVE Companion 0.8.0 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.")
$head.AppendChild($metaDescription) | Out-Null

$metaThemeColor = $html.CreateElement("meta")
$metaThemeColor.SetAttribute("name", "theme-color")
$metaThemeColor.SetAttribute("content", "#ffffff")
$head.AppendChild($metaThemeColor) | Out-Null

# Add link tags
$linkIcon = $html.CreateElement("link")
$linkIcon.SetAttribute("rel", "icon")
$linkIcon.SetAttribute("type", "image/png")
$linkIcon.SetAttribute("href", "/branding/staenderglobus-ios.png")
$head.AppendChild($linkIcon) | Out-Null

$linkAppleTouch = $html.CreateElement("link")
$linkAppleTouch.SetAttribute("rel", "apple-touch-icon")
$linkAppleTouch.SetAttribute("href", "/branding/staenderglobus-ios.png")
$head.AppendChild($linkAppleTouch) | Out-Null

# Add title
$title = $html.CreateElement("title")
$title.InnerText = "TikTok LIVE Companion – Dokumentation"
$head.AppendChild($title) | Out-Null

# Create body section
$body = $html.CreateElement("body")
$htmlElement.AppendChild($body) | Out-Null

# Add div with id=root
$divRoot = $html.CreateElement("div")
$divRoot.SetAttribute("id", "root")
$body.AppendChild($divRoot) | Out-Null

# Add script tag
$scriptTag = $html.CreateElement("script")
$scriptTag.SetAttribute("type", "module")
$scriptTag.SetAttribute("src", "/src/main.tsx")
$body.AppendChild($scriptTag) | Out-Null

# Save to file with proper formatting
$html.Save($OutputPath)

Write-Host "HTML file successfully generated at: $OutputPath"
