// abstraction-provenance: {"artifact_sha256": "1b3e78d9fc4bac0f2a8371eaa23d73a403e5cfa9167b1dc83244a859e5c1ce93", "source_sha256": "3c82de39b963e31592918456342c499f4e6477d2ee7404f215a5685c6d02674c", "target_language": "go"}
// ios-asc-keychain-setup.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-asc-keychain-setup.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

func usage() {
	fmt.Print(`Usage:
  scripts/ios-asc-keychain-setup.sh --key-path /path/to/AuthKey_XXXXXX.p8 --issuer-id <issuer-uuid> [options]

Required:
  --key-path <path>      Path to App Store Connect API key (.p8)
  --issuer-id <uuid>     App Store Connect issuer ID

Optional:
  --key-id <id>          API key ID (auto-detected from AuthKey_<id>.p8 if omitted)
  --service <name>       Keychain service name (default: openclaw-asc-key)
  --account <name>       Keychain account name (default: $USER or $LOGNAME)
  --write-env            Upsert non-secret env vars into apps/ios/fastlane/.env
  --env-file <path>      Override env file path used with --write-env
  -h, --help             Show this help

Example:
  scripts/ios-asc-keychain-setup.sh \
    --key-path "$HOME/keys/AuthKey_ABC1234567.p8" \
    --issuer-id "00000000-1111-2222-3333-444444444444" \
    --write-env
`)
}

func upsertEnvLine(file, key, value string) error {
	var lines []string
	if _, err := os.Stat(file); err == nil {
		f, err := os.Open(file)
		if err != nil {
			return err
		}
		defer f.Close()

		scanner := bufio.NewScanner(f)
		updated := false
		for scanner.Scan() {
			line := scanner.Text()
			if strings.HasPrefix(line, key+"=") {
				lines = append(lines, key+"="+value)
				updated = true
			} else {
				lines = append(lines, line)
			}
		}
		if !updated {
			lines = append(lines, key+"="+value)
		}
	} else {
		lines = append(lines, key+"="+value)
	}

	return writeLines(file, lines)
}

func deleteEnvLine(file, key string) error {
	if _, err := os.Stat(file); os.IsNotExist(err) {
		return nil
	}

	f, err := os.Open(file)
	if err != nil {
		return err
	}
	defer f.Close()

	var lines []string
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, key+"=") {
			lines = append(lines, line)
		}
	}

	return writeLines(file, lines)
}

func writeLines(file string, lines []string) error {
	tmpFile := file + ".tmp"
	f, err := os.Create(tmpFile)
	if err != nil {
		return err
	}
	defer f.Close()

	for _, line := range lines {
		_, err := f.WriteString(line + "\n")
		if err != nil {
			return err
		}
	}

	return os.Rename(tmpFile, file)
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Missing required arguments.")
		usage()
		os.Exit(1)
	}

	var keyPath, keyID, issuerID, service, account string
	var writeEnv bool
	var envFile string

	service = "openclaw-asc-key"
	account = os.Getenv("USER")
	if account == "" {
		account = os.Getenv("LOGNAME")
	}

	repoRoot, err := filepath.Abs(filepath.Join(filepath.Dir(os.Args[0]), ".."))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error determining repo root: %v\n", err)
		os.Exit(1)
	}
	defaultEnvFile := filepath.Join(repoRoot, "apps", "ios", "fastlane", ".env")

	args := os.Args[1:]
	i := 0
	for i < len(args) {
		arg := args[i]
		switch arg {
		case "--key-path":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --key-path")
				os.Exit(1)
			}
			keyPath = args[i+1]
			i += 2
		case "--key-id":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --key-id")
				os.Exit(1)
			}
			keyID = args[i+1]
			i += 2
		case "--issuer-id":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --issuer-id")
				os.Exit(1)
			}
			issuerID = args[i+1]
			i += 2
		case "--service":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --service")
				os.Exit(1)
			}
			service = args[i+1]
			i += 2
		case "--account":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --account")
				os.Exit(1)
			}
			account = args[i+1]
			i += 2
		case "--write-env":
			writeEnv = true
			i++
		case "--env-file":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --env-file")
				os.Exit(1)
			}
			envFile = args[i+1]
			i += 2
		case "-h", "--help":
			usage()
			os.Exit(0)
		default:
			fmt.Fprintf(os.Stderr, "Unknown argument: %s\n", arg)
			usage()
			os.Exit(1)
		}
	}

	if keyPath == "" || issuerID == "" {
		fmt.Fprintln(os.Stderr, "Missing required arguments.")
		usage()
		os.Exit(1)
	}

	if _, err := os.Stat(keyPath); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Key file not found: %s\n", keyPath)
		os.Exit(1)
	}

	if keyID == "" {
		keyFilename := filepath.Base(keyPath)
		re := regexp.MustCompile(`^AuthKey_([A-Za-z0-9]+)\.p8$`)
		matches := re.FindStringSubmatch(keyFilename)
		if len(matches) > 1 {
			keyID = matches[1]
		} else {
			fmt.Fprintf(os.Stderr, "Could not infer --key-id from filename '%s'. Pass --key-id explicitly.\n", keyFilename)
			os.Exit(1)
		}
	}

	if account == "" {
		fmt.Fprintln(os.Stderr, "Could not determine Keychain account. Pass --account explicitly.")
		os.Exit(1)
	}

	keyContentBytes, err := os.ReadFile(keyPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading key file: %v\n", err)
		os.Exit(1)
	}
	keyContent := string(keyContentBytes)
	if keyContent == "" {
		fmt.Fprintf(os.Stderr, "Key file is empty: %s\n", keyPath)
		os.Exit(1)
	}

	cmd := exec.Command("security", "add-generic-password",
		"-a", account,
		"-s", service,
		"-w", keyContent,
		"-U")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err = cmd.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error storing key in Keychain: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Stored ASC API private key in macOS Keychain (service='%s', account='%s').\n", service, account)
	fmt.Println()
	fmt.Println("Export these vars for Fastlane:")
	fmt.Printf("ASC_KEY_ID=%s\n", keyID)
	fmt.Printf("ASC_ISSUER_ID=%s\n", issuerID)
	fmt.Printf("ASC_KEYCHAIN_SERVICE=%s\n", service)
	fmt.Printf("ASC_KEYCHAIN_ACCOUNT=%s\n", account)

	if writeEnv {
		if envFile == "" {
			envFile = defaultEnvFile
		}

		dir := filepath.Dir(envFile)
		err := os.MkdirAll(dir, 0755)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error creating directory for env file: %v\n", err)
			os.Exit(1)
		}

		_, err = os.Stat(envFile)
		if os.IsNotExist(err) {
			f, err := os.Create(envFile)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error creating env file: %v\n", err)
				os.Exit(1)
			}
			f.Close()
		}

		err = upsertEnvLine(envFile, "ASC_KEY_ID", keyID)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error updating env file: %v\n", err)
			os.Exit(1)
		}

		err = upsertEnvLine(envFile, "ASC_ISSUER_ID", issuerID)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error updating env file: %v\n", err)
			os.Exit(1)
		}

		err = upsertEnvLine(envFile, "ASC_KEYCHAIN_SERVICE", service)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error updating env file: %v\n", err)
			os.Exit(1)
		}

		err = upsertEnvLine(envFile, "ASC_KEYCHAIN_ACCOUNT", account)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error updating env file: %v\n", err)
			os.Exit(1)
		}

		err = deleteEnvLine(envFile, "ASC_KEY_PATH")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error updating env file: %v\n", err)
			os.Exit(1)
		}

		err = deleteEnvLine(envFile, "ASC_KEY_CONTENT")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error updating env file: %v\n", err)
			os.Exit(1)
		}

		err = deleteEnvLine(envFile, "APP_STORE_CONNECT_API_KEY_PATH")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error updating env file: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("\nUpdated env file: %s\n", envFile)
	}
}
