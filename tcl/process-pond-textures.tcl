#!/usr/bin/env tclsh8.6
# process-pond-textures.py — portiert nach tcl
# Quelle: python, Onboarding@main:scripts/process-pond-textures.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Chroma-key pond textures to add a clean alpha channel.
#
# The leaf/blossom source webps ship on solid backgrounds (dark green or white)
# rather than transparency, so `alphaTest` clipping in three.js has nothing to
# key on. This produces RGBA PNGs with a soft alpha mask so the R3F planes clip
# to the real silhouette.

package require Img
package require math::statistics

set BASE "public/media/pond"
set OUT "public/media/pond/processed"

file mkdir $OUT

proc key_out {path out mode {feather 2.0}} {
    # Load image and convert to RGB if needed
    set img [image create photo -file $path -format WEBP]
    
    # Get image dimensions
    set width [image width $img]
    set height [image height $img]
    
    # Create arrays for RGB channels
    array set r {}
    array set g {}
    array set b {}
    
    # Extract pixel data
    for {set y 0} {$y < $height} {incr y} {
        for {set x 0} {$x < $width} {incr x} {
            set pixel [$img get $x $y]
            lassign [winfo rgb . $pixel] red green blue
            set r($x,$y) [expr {$red / 256}]
            set g($x,$y) [expr {$green / 256}]
            set b($x,$y) [expr {$blue / 256}]
        }
    }
    
    # Create alpha channel based on mode
    array set alpha {}
    
    if {$mode eq "green"} {
        # Dark-green background: low overall brightness AND green-dominant-but-dark.
        # Foreground leaf is much brighter / lighter green.
        for {set y 0} {$y < $height} {incr y} {
            for {set x 0} {$x < $width} {incr x} {
                set lum [expr {double($r($x,$y) + $g($x,$y) + $b($x,$y)) / 3.0}]
                # background pixels: very dark (lum < ~35) — the bg is ~(3,50,0)=17
                if {$lum < 40.0} {
                    set alpha($x,$y) 0
                } else {
                    set alpha($x,$y) 255
                }
            }
        }
    } elseif {$mode eq "white"} {
        # White background: near-white, low saturation.
        for {set y 0} {$y < $height} {incr y} {
            for {set x 0} {$x < $width} {incr x} {
                set mn [::math::min $r($x,$y) $g($x,$y) $b($x,$y)]
                set mx [::math::max $r($x,$y) $g($x,$y) $b($x,$y)]
                # background: bright and low chroma
                if {$mn > 218.0 && ($mx - $mn) < 28.0} {
                    set alpha($x,$y) 0
                } else {
                    set alpha($x,$y) 255
                }
            }
        }
    } else {
        error "Invalid mode: $mode"
    }
    
    # Apply Gaussian blur to alpha channel for feathering
    # Since we don't have direct access to Gaussian blur in pure Tcl,
    # we'll approximate it with a simple box blur repeated several times
    set blur_radius [expr {int($feather * 2)}]
    if {$blur_radius < 1} {set blur_radius 1}
    
    # Apply multiple passes of box blur to approximate Gaussian
    for {set pass 0} {$pass < 3} {incr pass} {
        array set blurred_alpha {}
        for {set y 0} {$y < $height} {incr y} {
            for {set x 0} {$x < $width} {incr x} {
                set sum 0
                set count 0
                for {set dy [expr {-$blur_radius}]} {$dy <= $blur_radius} {incr dy} {
                    for {set dx [expr {-$blur_radius}]} {$dx <= $blur_radius} {incr dx} {
                        set nx [expr {$x + $dx}]
                        set ny [expr {$y + $dy}]
                        if {$nx >= 0 && $nx < $width && $ny >= 0 && $ny < $height} {
                            incr sum $alpha($nx,$ny)
                            incr count
                        }
                    }
                }
                if {$count > 0} {
                    set blurred_alpha($x,$y) [expr {$sum / $count}]
                } else {
                    set blurred_alpha($x,$y) $alpha($x,$y)
                }
            }
        }
        array set alpha [array get blurred_alpha]
    }
    
    # Create new image with alpha channel
    set rgba_img [image create photo -width $width -height $height]
    
    # Copy original image data and apply alpha
    for {set y 0} {$y < $height} {incr y} {
        for {set x 0} {$x < $width} {incr x} {
            set r_val [format %02x [expr {int($r($x,$y))}]]
            set g_val [format %02x [expr {int($g($x,$y))}]]
            set b_val [format %02x [expr {int($b($x,$y))}]]
            set a_val [format %02x [expr {int($alpha($x,$y))}]]
            
            # Set pixel with alpha
            $rgba_img put "#$r_val$g_val$b_val$a_val" -to $x $y
        }
    }
    
    # Find bounding box (non-transparent pixels)
    set min_x $width
    set max_x -1
    set min_y $height
    set max_y -1
    
    for {set y 0} {$y < $height} {incr y} {
        for {set x 0} {$x < $width} {incr x} {
            if {$alpha($x,$y) > 0} {
                if {$x < $min_x} {set min_x $x}
                if {$x > $max_x} {set max_x $x}
                if {$y < $min_y} {set min_y $y}
                if {$y > $max_y} {set max_y $y}
            }
        }
    }
    
    # Crop if there's content
    if {$min_x <= $max_x && $min_y <= $max_y} {
        set cropped_img [image create photo -width [expr {$max_x - $min_x + 1}] -height [expr {$max_y - $min_y + 1}]]
        $cropped_img copy $rgba_img -from $min_x $min_y $max_x $max_y
        
        # Save cropped image
        $cropped_img write $out -format PNG
        puts "[file tail $path] -> [file tail $out] ([expr {$max_x - $min_x + 1}]x[expr {$max_y - $min_y + 1}]) ($mode)"
        
        # Clean up temporary image
        image delete $cropped_img
    } else {
        # No content found, save full image
        $rgba_img write $out -format PNG
        puts "[file tail $path] -> [file tail $out] (${width}x${height}) ($mode)"
    }
    
    # Clean up images
    image delete $img
    image delete $rgba_img
}

# Lily pads
key_out "$BASE/blaetter/12130585.webp" "$OUT/leaf-a.png" "green"
key_out "$BASE/blaetter/48178242.webp" "$OUT/leaf-b.png" "white"

# Blossoms with white backgrounds -> clean cutouts (only these two key cleanly)
key_out "$BASE/blueten/78370994.webp" "$OUT/blossom-a.png" "white" 3.0
key_out "$BASE/blueten/70017289.webp" "$OUT/blossom-b.png" "white" 3.0

puts "done"
