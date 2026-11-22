#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "bcc59b0f843b6c0c5eb970fb83abc66ef2b942914d42b721bb1f4b6f201a3b2a", "source_sha256": "b31f1bce542d41c8328b88079d7d58fa9d018f246f3f05fa532df8fe4ef6e153", "target_language": "tcl"}
# sandbox-common-setup.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-common-setup.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Set default values for environment variables
set BASE_IMAGE [expr {[info exists ::env(BASE_IMAGE)] ? $::env(BASE_IMAGE) : "openclaw-sandbox:bookworm-slim"}]
set TARGET_IMAGE [expr {[info exists ::env(TARGET_IMAGE)] ? $::env(TARGET_IMAGE) : "openclaw-sandbox-common:bookworm-slim"}]
set PACKAGES [expr {[info exists ::env(PACKAGES)] ? $::env(PACKAGES) : "curl wget jq coreutils grep nodejs npm python3 git ca-certificates golang-go rustc cargo unzip pkg-config libasound2-dev build-essential file"}]
set INSTALL_PNPM [expr {[info exists ::env(INSTALL_PNPM)] ? $::env(INSTALL_PNPM) : "1"}]
set INSTALL_BUN [expr {[info exists ::env(INSTALL_BUN)] ? $::env(INSTALL_BUN) : "1"}]
set BUN_INSTALL_DIR [expr {[info exists ::env(BUN_INSTALL_DIR)] ? $::env(BUN_INSTALL_DIR) : "/opt/bun"}]
set INSTALL_BREW [expr {[info exists ::env(INSTALL_BREW)] ? $::env(INSTALL_BREW) : "1"}]
set BREW_INSTALL_DIR [expr {[info exists ::env(BREW_INSTALL_DIR)] ? $::env(BREW_INSTALL_DIR) : "/home/linuxbrew/.linuxbrew"}]
set FINAL_USER [expr {[info exists ::env(FINAL_USER)] ? $::env(FINAL_USER) : "sandbox"}]
set OPENCLAW_DOCKER_BUILD_USE_BUILDX [expr {[info exists ::env(OPENCLAW_DOCKER_BUILD_USE_BUILDX)] ? $::env(OPENCLAW_DOCKER_BUILD_USE_BUILDX) : "0"}]
set OPENCLAW_DOCKER_BUILD_CACHE_FROM [expr {[info exists ::env(OPENCLAW_DOCKER_BUILD_CACHE_FROM)] ? $::env(OPENCLAW_DOCKER_BUILD_CACHE_FROM) : ""}]
set OPENCLAW_DOCKER_BUILD_CACHE_TO [expr {[info exists ::env(OPENCLAW_DOCKER_BUILD_CACHE_TO)] ? $::env(OPENCLAW_DOCKER_BUILD_CACHE_TO) : ""}]

# Check if base image exists
if {[catch {exec docker image inspect $BASE_IMAGE} result]} {
    puts "Base image missing: $BASE_IMAGE"
    puts "Building base image via scripts/sandbox-setup.sh..."
    if {[catch {exec scripts/sandbox-setup.sh} result]} {
        puts stderr "Failed to build base image: $result"
        exit 1
    }
}

puts "Building $TARGET_IMAGE with: $PACKAGES"

# Build command construction
set build_cmd "docker build"
if {$OPENCLAW_DOCKER_BUILD_USE_BUILDX eq "1"} {
    set build_cmd "docker buildx build --load"
    if {$OPENCLAW_DOCKER_BUILD_CACHE_FROM ne ""} {
        append build_cmd " --cache-from $OPENCLAW_DOCKER_BUILD_CACHE_FROM"
    }
    if {$OPENCLAW_DOCKER_BUILD_CACHE_TO ne ""} {
        append build_cmd " --cache-to $OPENCLAW_DOCKER_BUILD_CACHE_TO"
    }
}

# Execute the build command
set cmd "$build_cmd -t $TARGET_IMAGE -f Dockerfile.sandbox-common"
append cmd " --build-arg BASE_IMAGE=$BASE_IMAGE"
append cmd " --build-arg PACKAGES=$PACKAGES"
append cmd " --build-arg INSTALL_PNPM=$INSTALL_PNPM"
append cmd " --build-arg INSTALL_BUN=$INSTALL_BUN"
append cmd " --build-arg BUN_INSTALL_DIR=$BUN_INSTALL_DIR"
append cmd " --build-arg INSTALL_BREW=$INSTALL_BREW"
append cmd " --build-arg BREW_INSTALL_DIR=$BREW_INSTALL_DIR"
append cmd " --build-arg FINAL_USER=$FINAL_USER"
append cmd " ."

if {[catch {exec {*}$cmd} result]} {
    puts stderr "Build failed: $result"
    exit 1
}

# Output final instructions
puts "Built $TARGET_IMAGE."
puts "To use it, set agents.defaults.sandbox.docker.image to \"$TARGET_IMAGE\" and restart."
puts "If you want a clean re-create, remove old sandbox containers:"
puts "  docker rm -f \$(docker ps -aq --filter label=openclaw.sandbox=1)"
