#!/usr/bin/env pwsh
# index.html — portiert nach powershell
# Quelle: html, Projects@Program-Derivation:public/index.html
# auch in: Projects@Vision-Check:public/index.html
# auch in: Projects@Weather-Check:public/index.html
# auch in: Projects@abstractions:public/index.html
# auch in: 5 weiteren Fundstellen
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
    Erzeugt eine HTML-Weiterleitungsdatei.
.DESCRIPTION
    Dieses Skript erzeugt dynamisch eine HTML-Datei, die auf eine andere Seite weiterleitet.
    Es entspricht dem Inhalt der Datei index.html.
.PARAMETER OutputPath
    Der Pfad zur Ausgabedatei. Standardwert ist "./index.html".
.EXAMPLE
    ./create-redirect.ps1 -OutputPath "./meine-redirect.html"
#>

param(
    [string]$OutputPath = "./index.html"
)

# Erstellen des HTML-Dokuments als XML-Inhalt
$htmlDocument = New-Object System.Xml.XmlDocument

# DOCTYPE hinzufügen (nur als Kommentar, da XmlDocument keinen direkten DOCTYPE unterstützt)
# <!DOCTYPE html> wird später manuell eingefügt

# Root-Element <html>
$xmlHtml = $htmlDocument.CreateElement("html")
$xmlHtml.SetAttribute("lang", "de")
$htmlDocument.AppendChild($xmlHtml) | Out-Null

# Head-Bereich erstellen
$xmlHead = $htmlDocument.CreateElement("head")
$xmlHtml.AppendChild($xmlHead) | Out-Null

# Meta charset
$xmlMetaCharset = $htmlDocument.CreateElement("meta")
$xmlMetaCharset.SetAttribute("charset", "utf-8")
$xmlHead.AppendChild($xmlMetaCharset) | Out-Null

# Meta viewport
$xmlMetaViewport = $htmlDocument.CreateElement("meta")
$xmlMetaViewport.SetAttribute("name", "viewport")
$xmlMetaViewport.SetAttribute("content", "width=device-width, initial-scale=1")
$xmlHead.AppendChild($xmlMetaViewport) | Out-Null

# Meta refresh
$xmlMetaRefresh = $htmlDocument.CreateElement("meta")
$xmlMetaRefresh.SetAttribute("http-equiv", "refresh")
$xmlMetaRefresh.SetAttribute("content", "0; url=3d.html")
$xmlHead.AppendChild($xmlMetaRefresh) | Out-Null

# Title
$xmlTitle = $htmlDocument.CreateElement("title")
$xmlTitle.InnerText = "Weiterleitung zur 3D-Ansicht"
$xmlHead.AppendChild($xmlTitle) | Out-Null

# Link canonical
$xmlLinkCanonical = $htmlDocument.CreateElement("link")
$xmlLinkCanonical.SetAttribute("rel", "canonical")
$xmlLinkCanonical.SetAttribute("href", "3d.html")
$xmlHead.AppendChild($xmlLinkCanonical) | Out-Null

# Script für location.replace
$xmlScript = $htmlDocument.CreateElement("script")
$xmlScript.InnerText = "location.replace('3d.html');"
$xmlHead.AppendChild($xmlScript) | Out-Null

# Body-Bereich erstellen
$xmlBody = $htmlDocument.CreateElement("body")
$xmlHtml.AppendChild($xmlBody) | Out-Null

# Paragraph mit Link
$xmlP = $htmlDocument.CreateElement("p")
$xmlA = $htmlDocument.CreateElement("a")
$xmlA.SetAttribute("href", "3d.html")
$xmlA.InnerText = "3D-Ansicht öffnen"
$xmlP.AppendChild($xmlA) | Out-Null
$xmlBody.AppendChild($xmlP) | Out-Null

# Speichern des generierten HTML-Codes in eine temporäre Datei
$tempFile = [System.IO.Path]::GetTempFileName()
$htmlDocument.Save($tempFile)

# Lesen des Inhalts und Hinzufügen von <!DOCTYPE html> am Anfang
$htmlContent = Get-Content -Path $tempFile -Raw
$htmlWithDoctype = "<!DOCTYPE html>`n$htmlContent"

# Schreiben in die finale Ausgabedatei
Set-Content -Path $OutputPath -Value $htmlWithDoctype -Encoding Utf8

# Temporäre Datei löschen
Remove-Item -Path $tempFile -Force
