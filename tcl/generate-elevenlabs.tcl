#!/usr/bin/env tclsh
# generate-elevenlabs.mjs — portiert nach tcl
# Quelle: javascript, Onboarding@main:scripts/generate-elevenlabs.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

package require http
package require json
package require fileutil

# Hole Umgebungsvariablen
if {[info exists ::env(ELEVENLABS_API_KEY)]} {
    set key $::env(ELEVENLABS_API_KEY)
} else {
    error "ELEVENLABS_API_KEY fehlt."
}

# Setze Standard-Stimmen-ID falls nicht gesetzt
if {[info exists ::env(ELEVENLABS_VOICE_ID)] && $::env(ELEVENLABS_VOICE_ID) ne ""} {
    set voiceId $::env(ELEVENLABS_VOICE_ID)
} else {
    set voiceId "JBFqnCBsd6RMkjVDRZzb"
}

set text "Neun Projekte. Zwei Plattformen. Ein Ort, an dem Ideen verbunden und weiterentwickelt werden."

# Erstelle JSON-Body für den Request
set postData [::json::write object \
    text $text \
    model_id "eleven_multilingual_v2" \
    voice_settings [::json::write object \
        stability 0.58 \
        similarity_boost 0.72 \
        style 0.18 \
        use_speaker_boost true]]

# Setze Header
dict set headers "xi-api-key" $key
dict set headers "Content-Type" "application/json"

# Führe HTTP-POST-Request aus
set url "https://api.elevenlabs.io/v1/text-to-speech/${voiceId}?output_format=mp3_44100_128"
set token [http::geturl $url -method POST -headers $headers -query $postData]
set status [http::status $token]
set code [http::ncode $token]

# Prüfe auf Fehler
if {$status eq "error" || $code < 200 || $code >= 300} {
    set errorMsg [http::error $token]
    http::cleanup $token
    error "ElevenLabs fehlgeschlagen: $code $errorMsg"
}

# Hole Antwortdaten
set data [http::data $token]
http::cleanup $token]

# Erstelle Zielverzeichnis
file mkdir "../public/audio/"

# Schreibe MP3-Datei
set mp3File [open "../public/audio/project-narration.mp3" wb]
puts -nonewline $mp3File $data
close $mp3File

# Erstelle JSON-Ergebnisdatei
set resultJson [::json::write object \
    model "eleven_multilingual_v2" \
    voiceId $voiceId \
    characters [string length $text] \
    text $text \
    output "public/audio/project-narration.mp3"]

# Formatierung des JSON mit Einrückung
proc pretty_json {json_obj {indent 0}} {
    set result ""
    set indent_str [string repeat "  " $indent]
    
    if {[::json::json2dict $json_obj] eq $json_obj} {
        # Es ist ein einfacher Wert
        return $json_obj
    }
    
    # Prüfe ob Array
    if {[string index $json_obj 0] eq "\["} {
        append result "\[[\n"
        set first 1
        foreach item [lrange [::json::json2dict $json_obj] 0 end] {
            if {!$first} {
                append result ",[\n"
            }
            append result "[string repeat "  " [expr {$indent + 1}]][pretty_json $item [expr {$indent + 1}]]"
            set first 0
        }
        append result "[\n${indent_str}]"
    } else {
        # Es ist ein Objekt
        append result "{[\n"
        set dict_data [::json::json2dict $json_obj]
        set len [llength $dict_data]
        set i 0
        foreach {key value} $dict_data {
            append result "[string repeat "  " [expr {$indent + 1}]]\"$key\": "
            if {[string is list $value] && [llength $value] > 1} {
                # Geschachteltes Objekt oder Array
                append result "[pretty_json [::json::write object $key $value] [expr {$indent + 1}]]"
            } else {
                if {[string is double $value] || [string is integer $value]} {
                    append result "$value"
                } else {
                    append result "\"$value\""
                }
            }
            incr i
            if {$i < $len} {
                append result ","
            }
            append result "[\n"
        }
        append result "${indent_str}}"
    }
    return $result
}

# Da das native JSON-Paket keine schöne Formatierung bietet, verwenden wir eine vereinfachte Version
set formattedJson [::json::write object \
    model "eleven_multilingual_v2" \
    voiceId $voiceId \
    characters [string length $text] \
    text $text \
    output "public/audio/project-narration.mp3"]

# Schreibe Ergebnisdatei (ohne schöne Formatierung)
set jsonFile [open "../media-production/elevenlabs-result.json" w]
puts $jsonFile $formattedJson
close $jsonFile

puts "ElevenLabs abgeschlossen: [string length $text] Zeichen."
