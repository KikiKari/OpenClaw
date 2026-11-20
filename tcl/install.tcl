#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "b8c6e7c0645138763e5d142edb7dc4bb68b803bca21ae2173d8ab38e760b5157", "source_sha256": "4a2907e2ea521dc1e81ebd6e57ee9ab2269d633101a5fe398c3b55dfc0d99040", "target_language": "tcl"}
# install.ps1 — portiert nach tcl
# Quelle: powershell, workspace@local:skills/github-clones/openclaw/scripts/install.ps1
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# OpenClaw Installer for Windows (Tcl)
# Usage: tclsh install.tcl
# Or: tclsh install.tcl --no-onboard

package require http
package require tls

# Global variables with default values
set installMethod "npm"
set tag "latest"
set gitDir [file join $env(USERPROFILE) openclaw]
set noOnboard false
set noGitUpdate false
set dryRun false

# Colors (ANSI escape codes)
set ACCENT "\033\[38;2;255;77;77m"    ;# coral-bright
set SUCCESS "\033\[38;2;0;229;204m"   ;# cyan-bright
set WARN "\033\[38;2;255;176;32m"     ;# amber
set ERROR "\033\[38;2;230;57;70m"     ;# coral-mid
set MUTED "\033\[38;2;90;100;128m"    ;# text-muted
set NC "\033\[0m"                      ;# No Color

proc writeHost {message {level "info"}} {
    global SUCCESS WARN ERROR MUTED NC
    switch $level {
        "success" {
            puts "${SUCCESS}✓${NC} $message"
        }
        "warn" {
            puts "${WARN}!${NC} $message"
        }
        "error" {
            puts "${ERROR}✗${NC} $message"
        }
        default {
            puts "${MUTED}·${NC} $message"
        }
    }
}

proc writeBanner {} {
    global ACCENT MUTED NC
    writeHost ""
    writeHost "${ACCENT}  🦞 OpenClaw Installer${NC}" "info"
    writeHost "${MUTED}  All your chats, one OpenClaw.${NC}" "info"
    writeHost ""
}

proc testAdmin {} {
    # On Windows, we can check if we have admin rights by trying to access a protected directory
    if {[catch {exec fsutil dirty query c:}]} {
        return 0
    } else {
        return 1
    }
}

proc getNodeVersion {} {
    if {[catch {exec node --version} version]} {
        return ""
    }
    regsub {^v} $version "" version
    return $version
}

proc getNpmVersion {} {
    if {[catch {exec npm --version} version]} {
        return ""
    }
    return $version
}

proc installNode {} {
    writeHost "Node.js not found" "info"
    writeHost "Installing Node.js..." "info"
    
    # Try winget first
    if {[catch {exec where winget}]} {
        writeHost "winget not found" "warn"
    } else {
        writeHost "  Using winget..." "info"
        if {[catch {exec winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements} result]} {
            writeHost "  Winget install failed: $result" "warn"
        } else {
            writeHost "  Node.js installed via winget" "success"
            return 1
        }
    }
    
    # Try chocolatey
    if {[catch {exec where choco}]} {
        writeHost "chocolatey not found" "warn"
    } else {
        writeHost "  Using chocolatey..." "info"
        if {[catch {exec choco install nodejs-lts -y} result]} {
            writeHost "  Chocolatey install failed: $result" "warn"
        } else {
            writeHost "  Node.js installed via chocolatey" "success"
            return 1
        }
    }
    
    # Try scoop
    if {[catch {exec where scoop}]} {
        writeHost "scoop not found" "warn"
    } else {
        writeHost "  Using scoop..." "info"
        if {[catch {exec scoop install nodejs-lts} result]} {
            writeHost "  Scoop install failed: $result" "warn"
        } else {
            writeHost "  Node.js installed via scoop" "success"
            return 1
        }
    }
    
    writeHost "Could not install Node.js automatically" "error"
    writeHost "Please install Node.js 22+ manually from: https://nodejs.org" "info"
    return 0
}

proc ensureNode {} {
    set nodeVersion [getNodeVersion]
    if {$nodeVersion ne ""} {
        regexp {^(\d+)} $nodeVersion -> major
        if {$major >= 22} {
            writeHost "Node.js v$nodeVersion found" "success"
            return 1
        }
        writeHost "Node.js v$nodeVersion found, but need v22+" "warn"
    }
    return [installNode]
}

proc getGitVersion {} {
    if {[catch {exec git --version} version]} {
        return ""
    }
    return $version
}

proc installGit {} {
    writeHost "Git not found" "info"
    
    if {[catch {exec where winget}]} {
        writeHost "winget not found" "warn"
    } else {
        writeHost "  Installing Git via winget..." "info"
        if {[catch {exec winget install Git.Git --accept-package-agreements --accept-source-agreements} result]} {
            writeHost "  Winget install failed" "warn"
        } else {
            writeHost "  Git installed" "success"
            return 1
        }
    }
    
    writeHost "Please install Git for Windows from: https://git-scm.com" "error"
    return 0
}

proc ensureGit {} {
    set gitVersion [getGitVersion]
    if {$gitVersion ne ""} {
        writeHost "$gitVersion found" "success"
        return 1
    }
    return [installGit]
}

proc installOpenClawNpm {target} {
    set installSpec [resolvePackageInstallSpec $target]
    
    writeHost "Installing OpenClaw ($installSpec)..." "info"
    
    if {[catch {exec npm install -g $installSpec --no-fund --no-audit} result]} {
        writeHost "npm install failed: $result" "error"
        return 0
    } else {
        writeHost "OpenClaw installed" "success"
        return 1
    }
}

proc installOpenClawGit {repoDir update} {
    writeHost "Installing OpenClaw from git..." "info"
    
    if {![file exists $repoDir]} {
        writeHost "  Cloning repository..." "info"
        if {[catch {exec git clone https://github.com/openclaw/openclaw.git $repoDir} result]} {
            writeHost "Clone failed: $result" "error"
            return 0
        }
    } elseif {$update} {
        writeHost "  Updating repository..." "info"
        if {[catch {exec git -C $repoDir pull --rebase} result]} {
            writeHost "Pull failed: $result" "error"
            return 0
        }
    }
    
    # Install pnpm if not present
    if {[catch {exec where pnpm}]} {
        writeHost "  Installing pnpm..." "info"
        if {[catch {exec npm install -g pnpm} result]} {
            writeHost "pnpm install failed: $result" "error"
            return 0
        }
    }
    
    # Install dependencies
    writeHost "  Installing dependencies..." "info"
    if {[catch {exec pnpm install --dir $repoDir} result]} {
        writeHost "Dependency install failed: $result" "error"
        return 0
    }
    
    # Build
    writeHost "  Building..." "info"
    if {[catch {exec pnpm --dir $repoDir build} result]} {
        writeHost "Build failed: $result" "error"
        return 0
    }
    
    # Create wrapper
    set wrapperDir [file join $env(USERPROFILE) .local bin]
    if {![file exists $wrapperDir]} {
        file mkdir $wrapperDir
    }
    
    set wrapperFile [file join $wrapperDir openclaw.cmd]
    set fh [open $wrapperFile w]
    puts $fh "@echo off"
    puts $fh {node "%~dp0..\openclaw\dist\entry.js" %*}
    close $fh
    
    writeHost "OpenClaw installed" "success"
    return 1
}

proc testExplicitPackageInstallSpec {target} {
    if {$target eq ""} {
        return 0
    }
    
    if {[string match "*://*" $target] || 
        [string match "*#*" $target] ||
        [regexp {^(file|github|git\+ssh|git\+https|git\+http|git\+file|npm):} $target]} {
        return 1
    }
    return 0
}

proc resolvePackageInstallSpec {{target "latest"}} {
    set trimmed [string trim $target]
    if {$trimmed eq ""} {
        return "openclaw@latest"
    }
    if {[string tolower $trimmed] eq "main"} {
        return "github:openclaw/openclaw#main"
    }
    if {[testExplicitPackageInstallSpec $trimmed]} {
        return $trimmed
    }
    return "openclaw@$trimmed"
}

proc addToPath {pathToAdd} {
    set currentPath $env(PATH)
    if {![string match "*$pathToAdd*" $currentPath]} {
        set env(PATH) "$currentPath;$pathToAdd"
        writeHost "Added $pathToAdd to user PATH" "info"
    }
}

proc parseArgs {argv} {
    global installMethod tag gitDir noOnboard noGitUpdate dryRun
    
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        switch -glob $arg {
            "--install-method=*" {
                set installMethod [string range $arg 17 end]
            }
            "--tag=*" {
                set tag [string range $arg 7 end]
            }
            "--git-dir=*" {
                set gitDir [string range $arg 10 end]
            }
            "--no-onboard" {
                set noOnboard true
            }
            "--no-git-update" {
                set noGitUpdate true
            }
            "--dry-run" {
                set dryRun true
            }
            "-*" {
                writeHost "Unknown option: $arg" "warn"
            }
        }
    }
}

proc main {argv} {
    parseArgs $argv
    writeBanner
    
    writeHost "Windows detected" "success"
    
    if {![ensureNode]} {
        exit 1
    }
    
    if {$installMethod eq "git"} {
        if {![ensureGit]} {
            exit 1
        }
        
        if {$dryRun} {
            writeHost "\[DRY RUN\] Would install OpenClaw from git to $gitDir" "info"
        } else {
            if {![installOpenClawGit $gitDir [expr {!$noGitUpdate}]]} {
                exit 1
            }
        }
    } else {
        # npm method
        if {![ensureGit]} {
            writeHost "Git is required for npm installs. Please install Git and try again." "warn"
        }
        
        if {$dryRun} {
            writeHost "\[DRY RUN\] Would install OpenClaw via npm ([resolvePackageInstallSpec $tag])" "info"
        } else {
            if {![installOpenClawNpm $tag]} {
                exit 1
            }
        }
    }
    
    # Try to add npm global bin to PATH
    if {[catch {exec npm config get prefix} npmPrefix]} {
        # Ignore error
    } else {
        addToPath $npmPrefix
    }
    
    if {!$noOnboard && !$dryRun} {
        writeHost ""
        writeHost "Run 'openclaw onboard' to complete setup" "info"
    }
    
    writeHost ""
    writeHost "🦞 OpenClaw installed successfully!" "success"
}

# Entry point
main $argv
