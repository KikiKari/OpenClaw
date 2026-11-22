// abstraction-provenance: {"artifact_sha256": "49abff71464c3ebb08bc14acbee0a5ebede7549ad88225b7b1015f5994140e2a", "source_sha256": "29aab8d3e497ddaa7ec77edf107b153fe17970d064df8a91d7cfcedb7e30a7fd", "target_language": "go"}
// sandbox-browser-entrypoint.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-browser-entrypoint.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"
)

func main() {
	os.Setenv("DBUS_SESSION_BUS_ADDRESS", "/dev/null")

	os.Setenv("DISPLAY", ":1")
	home := "/tmp/openclaw-home"
	os.Setenv("HOME", home)
	os.Setenv("XDG_CONFIG_HOME", home+"/.config")
	os.Setenv("XDG_CACHE_HOME", home+"/.cache")

	cdpPort := getEnvOrDefault("OPENCLAW_BROWSER_CDP_PORT", "9222")
	cdpSourceRange := os.Getenv("OPENCLAW_BROWSER_CDP_SOURCE_RANGE")
	vncPort := getEnvOrDefault("OPENCLAW_BROWSER_VNC_PORT", "5900")
	novncPort := getEnvOrDefault("OPENCLAW_BROWSER_NOVNC_PORT", "6080")
	enableNovnc := getEnvOrDefault("OPENCLAW_BROWSER_ENABLE_NOVNC", "1")
	headless := getEnvOrDefault("OPENCLAW_BROWSER_HEADLESS", "0")
	allowNoSandbox := getEnvOrDefault("OPENCLAW_BROWSER_NO_SANDBOX", "0")
	novncPassword := os.Getenv("OPENCLAW_BROWSER_NOVNC_PASSWORD")

	disableGraphicsFlags := getEnvOrDefault("OPENCLAW_BROWSER_DISABLE_GRAPHICS_FLAGS", "1")
	disableExtensions := getEnvOrDefault("OPENCLAW_BROWSER_DISABLE_EXTENSIONS", "1")
	rendererProcessLimit := getEnvOrDefault("OPENCLAW_BROWSER_RENDERER_PROCESS_LIMIT", "2")
	autoStartTimeoutMs := getEnvOrDefault("OPENCLAW_BROWSER_AUTO_START_TIMEOUT_MS", "12000")

	validateUint("CDP_PORT", cdpPort, 1, 65535)
	validateUint("VNC_PORT", vncPort, 1, 65535)
	validateUint("NOVNC_PORT", novncPort, 1, 65535)
	validateUint("AUTO_START_TIMEOUT_MS", autoStartTimeoutMs, 1, 2147483647)
	if rendererProcessLimit != "" {
		validateUint("RENDERER_PROCESS_LIMIT", rendererProcessLimit, 0, 2147483647)
	}

	cleanup := func(code int) {
		pids := []int{}
		if xvfbPidStr := os.Getenv("XVFB_PID"); xvfbPidStr != "" {
			if pid, err := strconv.Atoi(xvfbPidStr); err == nil {
				pids = append(pids, pid)
			}
		}
		if chromePidStr := os.Getenv("CHROME_PID"); chromePidStr != "" {
			if pid, err := strconv.Atoi(chromePidStr); err == nil {
				pids = append(pids, pid)
			}
		}
		if socatPidStr := os.Getenv("SOCAT_PID"); socatPidStr != "" {
			if pid, err := strconv.Atoi(socatPidStr); err == nil {
				pids = append(pids, pid)
			}
		}
		if x11vncPidStr := os.Getenv("X11VNC_PID"); x11vncPidStr != "" {
			if pid, err := strconv.Atoi(x11vncPidStr); err == nil {
				pids = append(pids, pid)
			}
		}
		if webrtcPidStr := os.Getenv("WEBSOCKIFY_PID"); webrtcPidStr != "" {
			if pid, err := strconv.Atoi(webrtcPidStr); err == nil {
				pids = append(pids, pid)
			}
		}

		if len(pids) > 0 {
			for _, pid := range pids {
				syscall.Kill(pid, syscall.SIGTERM)
			}

			for i := 0; i < 10; i++ {
				allDead := true
				for _, pid := range pids {
					if err := syscall.Kill(pid, 0); err == nil {
						allDead = false
						break
					}
				}
				if allDead {
					break
				}
				time.Sleep(200 * time.Millisecond)
			}

			for _, pid := range pids {
				syscall.Kill(pid, syscall.SIGKILL)
			}
		}

		os.Exit(code)
	}

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	go func() {
		sig := <-sigChan
		if sig == os.Interrupt {
			cleanup(130)
		} else if sig == syscall.SIGTERM {
			cleanup(143)
		}
	}()

	os.MkdirAll(home, 0755)
	os.MkdirAll(home+"/.chrome", 0755)
	os.MkdirAll(os.Getenv("XDG_CONFIG_HOME"), 0755)
	os.MkdirAll(os.Getenv("XDG_CACHE_HOME"), 0755)

	xvfbCmd := exec.Command("Xvfb", ":1", "-screen", "0", "1280x800x24", "-ac", "-nolisten", "tcp")
	xvfbCmd.Start()
	xvfbPid := xvfbCmd.Process.Pid
	fmt.Printf("[sandbox] Xvfb started (PID: %d)\n", xvfbPid)
	os.Setenv("XVFB_PID", strconv.Itoa(xvfbPid))

	chromeCdpPort := 0
	cdpPortInt, _ := strconv.Atoi(cdpPort)
	if cdpPortInt >= 65535 {
		chromeCdpPort = cdpPortInt - 1
	} else {
		chromeCdpPort = cdpPortInt + 1
	}

	chromeArgs := []string{
		"--remote-debugging-address=127.0.0.1",
		"--remote-debugging-port=" + strconv.Itoa(chromeCdpPort),
		"--user-data-dir=" + home + "/.chrome",
		"--no-first-run",
		"--no-default-browser-check",
		"--disable-dev-shm-usage",
		"--disable-background-networking",
		"--disable-breakpad",
		"--disable-crash-reporter",
		"--no-zygote",
		"--metrics-recording-only",
		"--password-store=basic",
		"--use-mock-keychain",
	}

	if headless == "1" {
		chromeArgs = append(chromeArgs, "--headless=new")
	}

	if allowNoSandbox == "1" {
		chromeArgs = append(chromeArgs, "--no-sandbox", "--disable-setuid-sandbox")
	}

	disableGraphicsFlagsLower := strings.ToLower(disableGraphicsFlags)
	if disableGraphicsFlagsLower == "1" || disableGraphicsFlagsLower == "true" || disableGraphicsFlagsLower == "yes" || disableGraphicsFlagsLower == "on" {
		chromeArgs = append(chromeArgs,
			"--disable-3d-apis",
			"--disable-gpu",
			"--disable-software-rasterizer")
	}

	disableExtensionsLower := strings.ToLower(disableExtensions)
	if disableExtensionsLower == "1" || disableExtensionsLower == "true" || disableExtensionsLower == "yes" || disableExtensionsLower == "on" {
		chromeArgs = append(chromeArgs, "--disable-extensions")
	}

	if rendererProcessLimit != "" {
		rendererLimitInt, err := strconv.Atoi(rendererProcessLimit)
		if err == nil && rendererLimitInt > 0 {
			chromeArgs = append(chromeArgs, "--renderer-process-limit="+rendererProcessLimit)
		}
	}

	fmt.Println("[sandbox] Starting Chromium...")
	chromeCmd := exec.Command("chromium", chromeArgs...)
	chromeCmd.Args = append([]string{"chromium"}, chromeArgs...)
	chromeCmd.Start()
	chromePid := chromeCmd.Process.Pid
	fmt.Printf("[sandbox] Chromium started (PID: %d)\n", chromePid)
	os.Setenv("CHROME_PID", strconv.Itoa(chromePid))

	startMs := time.Now().UnixNano() / int64(time.Millisecond)
	autoStartTimeoutMsInt, _ := strconv.ParseInt(autoStartTimeoutMs, 10, 64)
	deadlineMs := startMs + autoStartTimeoutMsInt
	cdpReady := false
	probeUrl := "http://127.0.0.1:" + strconv.Itoa(chromeCdpPort) + "/json/version"

	fmt.Printf("[sandbox] Waiting up to %s ms for CDP on port %d...\n", autoStartTimeoutMs, chromeCdpPort)

	for time.Now().UnixNano()/int64(time.Millisecond) < deadlineMs {
		if err := syscall.Kill(chromePid, 0); err != nil {
			fmt.Println("[sandbox] ERROR: Chromium exited before CDP became ready.")
			os.Exit(1)
		}

		curlCmd := exec.Command("curl", "-fsS", "--max-time", "0.5", probeUrl)
		if err := curlCmd.Run(); err == nil {
			cdpReady = true
			break
		}

		time.Sleep(200 * time.Millisecond)
	}

	if !cdpReady {
		fmt.Printf("[sandbox] ERROR: CDP failed to start within %s ms.\n", autoStartTimeoutMs)
		os.Exit(1)
	}

	fmt.Println("[sandbox] CDP ready. Starting socat...")

	if cdpSourceRange == "" {
		fmt.Fprintln(os.Stderr, "[sandbox-browser] WARNING: CDP_SOURCE_RANGE unset; socat CDP relay will not start.")
		fmt.Fprintln(os.Stderr, "[sandbox-browser] Set OPENCLAW_BROWSER_CDP_SOURCE_RANGE to an explicit CIDR to enable CDP access.")
	} else {
		socatListenAddr := "TCP-LISTEN:" + cdpPort + ",fork,reuseaddr,bind=0.0.0.0,range=" + cdpSourceRange
		socatCmd := exec.Command("socat", socatListenAddr, "TCP:127.0.0.1:"+strconv.Itoa(chromeCdpPort))
		socatCmd.Start()
		socatPid := socatCmd.Process.Pid
		fmt.Printf("[sandbox] socat started (PID: %d)\n", socatPid)
		os.Setenv("SOCAT_PID", strconv.Itoa(socatPid))
	}

	if enableNovnc == "1" && headless != "1" {
		if novncPassword == "" {
			uuidBytes, _ := os.ReadFile("/proc/sys/kernel/random/uuid")
			uuidStr := string(uuidBytes)
			novncPassword = strings.ReplaceAll(uuidStr, "-", "")
			if len(novncPassword) > 8 {
				novncPassword = novncPassword[:8]
			}
		}

		os.MkdirAll(home+"/.vnc", 0755)
		x11vncStoreCmd := exec.Command("x11vnc", "-storepasswd", novncPassword, home+"/.vnc/passwd")
		x11vncStoreCmd.Run()
		os.Chmod(home+"/.vnc/passwd", 0600)

		x11vncCmd := exec.Command("x11vnc", "-display", ":1", "-rfbport", vncPort, "-shared", "-forever", "-rfbauth", home+"/.vnc/passwd", "-localhost")
		x11vncCmd.Start()
		x11vncPid := x11vncCmd.Process.Pid
		fmt.Printf("[sandbox] x11vnc started (PID: %d)\n", x11vncPid)
		os.Setenv("X11VNC_PID", strconv.Itoa(x11vncPid))

		websockifyCmd := exec.Command("websockify", "--web", "/usr/share/novnc/", novncPort, "localhost:"+vncPort)
		websockifyCmd.Start()
		webrtcPid := websockifyCmd.Process.Pid
		fmt.Printf("[sandbox] websockify started (PID: %d)\n", webrtcPid)
		os.Setenv("WEBSOCKIFY_PID", strconv.Itoa(webrtcPid))
	}

	fmt.Println("[sandbox] Container running. Monitoring all sub-processes...")
	select {}
}

func getEnvOrDefault(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

func validateUint(name, value string, min, max int) {
	if _, err := strconv.Atoi(value); err != nil {
		fmt.Fprintf(os.Stderr, "[sandbox] ERROR: %s must be an integer, got: %s\n", name, value)
		os.Exit(1)
	}
	
	intValue, _ := strconv.Atoi(value)
	if intValue < min || intValue > max {
		fmt.Fprintf(os.Stderr, "[sandbox] ERROR: %s out of range (%d..%d), got: %s\n", name, min, max, value)
		os.Exit(1)
	}
}
