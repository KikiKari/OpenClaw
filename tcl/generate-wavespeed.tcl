#!/usr/bin/env tclsh
# generate-wavespeed.mjs — portiert nach tcl
# Quelle: javascript, Onboarding@main:scripts/generate-wavespeed.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

package require http
package require json
package require fileutil
package require base64

# Set HTTP timeout to 5 minutes
http::config -timeout 300000

# Get API key from environment variable
if {![info exists ::env(WAVESPEED_API_KEY)] || $::env(WAVESPEED_API_KEY) eq ""} {
    error "WAVESPEED_API_KEY fehlt."
}
set key $::env(WAVESPEED_API_KEY)

# Define paths
set scriptDir [file dirname [info script]]
set jobsFile [file join $scriptDir ".." "media-production" "wavespeed-jobs.json"]
set rawDir [file join $scriptDir ".." "media-production" "raw"]
set publicDir [file join $scriptDir ".." "public" "media"]
set resultUrl [file join $scriptDir ".." "media-production" "wavespeed-results.json"]

# Create directories
file mkdir $rawDir
file mkdir $publicDir

# Read jobs file
set jobsData [readFile $jobsFile]
set jobs [json::json2dict $jobsData]

# Read or initialize log
if {[file exists $resultUrl]} {
    set logData [readFile $resultUrl]
    set log [json::json2dict $logData]
} else {
    set log [list]
}

# Process each job
foreach jobDict $jobs {
    set jobId [dict get $jobDict "id"]
    set outputName [dict get $jobDict "output"]
    
    set rawPath [file join $rawDir "${jobId}.png"]
    set targetPath [file join $publicDir "${outputName}.png"]
    
    # Check if already generated
    if {[file exists $rawPath]} {
        set foundInLog 0
        foreach entry $log {
            if {[dict get $entry "id"] eq $jobId} {
                set foundInLog 1
                break
            }
        }
        
        if {!$foundInLog} {
            lappend log [dict create \
                "id" $jobId \
                "requestId" "completed-before-resume" \
                "model" "google/nano-banana-2/edit" \
                "resolution" "4k" \
                "plannedCostUsd" 0.14 \
                "output" [file tail $targetPath]]
            
            writeJsonFile $resultUrl $log
        }
        
        puts "Übersprungen: $jobId ist bereits vorhanden."
        continue
    }
    
    # Prepare images
    set imagesList [dict get $jobDict "images"]
    set processedImages {}
    
    foreach image $imagesList {
        if {[regexp {^(https?|data):} $image]} {
            lappend processedImages $image
        } else {
            set imagePath [file join $scriptDir ".." $image]
            set imageData [readBinaryFile $imagePath]
            set encodedImage [base64::encode $imageData]
            lappend processedImages "data:image/png;base64,$encodedImage"
        }
    }
    
    # Submit job
    set submitUrl "https://api.wavespeed.ai/api/v3/google/nano-banana-2/edit"
    set prompt [dict get $jobDict "prompt"]
    set aspectRatio [dict get $jobDict "aspectRatio"]
    
    set postData [createSubmitPayload $prompt $processedImages $aspectRatio]
    set response [submitRequest $submitUrl $key $postData]
    
    if {[dict get $response "status"] != 200} {
        set detail [dict get $response "body"]
        error "WaveSpeed submit fehlgeschlagen: [dict get $response "status"] $detail"
    }
    
    set responseBody [dict get $response "body"]
    set submitted [json::json2dict $responseBody]
    set requestId [getRequestId $submitted]
    
    # Poll for completion
    set result [pollForResult $requestId $key]
    
    # Get output URL and download image
    set imageUrl [getImageUrlFromResult $result]
    if {$imageUrl eq ""} {
        error "Kein Output für $jobId"
    }
    
    set imageBytes [downloadImage $imageUrl]
    writeBinaryFile $rawPath $imageBytes
    writeBinaryFile $targetPath $imageBytes
    
    # Update log
    lappend log [dict create \
        "id" $jobId \
        "requestId" $requestId \
        "model" "google/nano-banana-2/edit" \
        "resolution" "4k" \
        "plannedCostUsd" 0.14 \
        "output" [file tail $targetPath]]
    
    writeJsonFile $resultUrl $log
    puts "Abgeschlossen: $jobId"
}

writeJsonFile $resultUrl $log

# Calculate total cost
set count [llength $log]
set totalCost [expr {$count * 0.14}]
puts [format "WaveSpeed abgeschlossen: %d Assets, geplante Basiskosten \$%.2f." $count $totalCost]


# Helper procedures

proc readFile {filename} {
    set fh [open $filename r]
    set data [read $fh]
    close $fh
    return $data
}

proc readBinaryFile {filename} {
    set fh [open $filename rb]
    fconfigure $fh -translation binary
    set data [read $fh]
    close $fh
    return $data
}

proc writeBinaryFile {filename data} {
    set fh [open $filename wb]
    fconfigure $fh -translation binary
    puts -nonewline $fh $data
    close $fh
}

proc writeJsonFile {filename data} {
    set fh [open $filename w]
    puts $fh [json::dict2json $data]
    close $fh
}

proc createSubmitPayload {prompt images aspectRatio} {
    set payload [dict create \
        "prompt" $prompt \
        "images" $images \
        "aspect_ratio" $aspectRatio \
        "resolution" "4k" \
        "output_format" "png" \
        "enable_web_search" false \
        "enable_image_search" false \
        "enable_sync_mode" false \
        "enable_base64_output" false]
    
    return [json::dict2json $payload]
}

proc submitRequest {url key jsonData} {
    set token [http::geturl $url \
        -headers [list \
            "Authorization" "Bearer $key" \
            "Content-Type" "application/json"] \
        -method POST \
        -query $jsonData]
    
    set status [http::status $token]
    set code [http::ncode $token]
    set body [http::data $token]
    http::cleanup $token
    
    return [dict create "status" $code "body" $body]
}

proc getRequestId {submitted} {
    if {[dict exists $submitted "data" "id"]} {
        return [dict get $submitted "data" "id"]
    } elseif {[dict exists $submitted "id"]} {
        return [dict get $submitted "id"]
    } else {
        error "Could not find request ID in response"
    }
}

proc pollForResult {requestId key} {
    set maxAttempts 90
    set delay 4000
    
    for {set attempt 0} {$attempt < $maxAttempts} {incr attempt} {
        after $delay
        
        set pollUrl "https://api.wavespeed.ai/api/v3/predictions/$requestId/result"
        set token [http::geturl $pollUrl \
            -headers [list "Authorization" "Bearer $key"]]
        
        set status [http::status $token]
        set code [http::ncode $token]
        set body [http::data $token]
        http::cleanup $token
        
        if {$status eq "ok" && $code == 200} {
            set result [json::json2dict $body]
            if {[dict exists $result "data" "status"]} {
                set jobStatus [dict get $result "data" "status"]
                if {$jobStatus eq "completed"} {
                    return $result
                } elseif {$jobStatus eq "failed"} {
                    error "WaveSpeed job fehlgeschlagen: $requestId"
                }
            }
        }
    }
    
    error "Max polling attempts reached for request $requestId"
}

proc getImageUrlFromResult {result} {
    if {[dict exists $result "data" "outputs" 0]} {
        return [dict get $result "data" "outputs" 0]
    } else {
        return ""
    }
}

proc downloadImage {url} {
    set token [http::geturl $url]
    set status [http::status $token]
    set body [http::data $token]
    http::cleanup $token
    
    if {$status eq "ok"} {
        return $body
    } else {
        error "Failed to download image from $url"
    }
}
