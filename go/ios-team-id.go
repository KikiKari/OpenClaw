// abstraction-provenance: {"artifact_sha256": "8bb86fa8c89965aa09ac1d7ccc7ac5577468688d939064c8cc6de8a4da09dff1", "source_sha256": "ff0a573c1d18ce8554e3d7311f3c2ae463c9664ad4b824e0cb5888b499733213", "target_language": "go"}
// ios-team-id.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-team-id.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

func main() {
	if team := os.Getenv("IOS_DEVELOPMENT_TEAM"); team != "" {
		fmt.Println(team)
		os.Exit(0)
	}

	preferredTeam := getEnvOrDefault("IOS_PREFERRED_TEAM_ID", getEnvOrDefault("OPENCLAW_IOS_DEFAULT_TEAM_ID", "Y5PE65HELJ"))
	preferredTeam = strings.ReplaceAll(preferredTeam, "\r", "")
	
	preferredTeamName := os.Getenv("IOS_PREFERRED_TEAM_NAME")
	if preferredTeamName != "" {
		preferredTeamName = strings.ReplaceAll(preferredTeamName, "\r", "")
	}
	
	allowKeychainFallback := os.Getenv("IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK") == "1"
	preferNonFreeTeam := os.Getenv("IOS_PREFER_NON_FREE_TEAM") != "0"

	var teamIDs []string
	var teamIsFree []bool
	var teamNames []string
	
	// Load teams from various sources
	loadTeamsFromXcodePreferences(&teamIDs, &teamIsFree, &teamNames)
	loadTeamsFromLegacyDefaultsKey(&teamIDs, &teamIsFree, &teamNames)
	
	if len(teamIDs) == 0 {
		loadTeamsFromXcodeManagedProfiles(&teamIDs, &teamIsFree, &teamNames)
	}
	
	if len(teamIDs) == 0 && allowKeychainFallback {
		loadTeamsFromKeychain(&teamIDs, &teamIsFree, &teamNames)
	}
	
	if len(teamIDs) == 0 {
		if hasXcodeAccount() {
			fmt.Fprintln(os.Stderr, "An Apple account is signed in to Xcode, but no Team ID could be resolved.")
			fmt.Fprintln(os.Stderr, "")
			fmt.Fprintln(os.Stderr, "On Xcode 16+, team data is not written until you build a project.")
			fmt.Fprintln(os.Stderr, "To fix this, do ONE of the following:")
			fmt.Fprintln(os.Stderr, "")
			fmt.Fprintln(os.Stderr, "  1. Open the iOS project in Xcode, select your Team in Signing &")
			fmt.Fprintln(os.Stderr, "     Capabilities, and build once. Then re-run this script.")
			fmt.Fprintln(os.Stderr, "")
			fmt.Fprintln(os.Stderr, "  2. Set your Team ID directly:")
			fmt.Fprintln(os.Stderr, "       export IOS_DEVELOPMENT_TEAM=<your-10-char-team-id>")
			fmt.Fprintln(os.Stderr, "     Find your Team ID at: https://developer.apple.com/account#MembershipDetailsCard")
		} else if allowKeychainFallback {
			fmt.Fprintln(os.Stderr, "No Apple Team ID found. Open Xcode or install signing certificates first.")
		} else {
			fmt.Fprintln(os.Stderr, "No Apple Team ID found in Xcode accounts. Open Xcode → Settings → Accounts and sign in, then retry.")
			fmt.Fprintln(os.Stderr, "(Set IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK=1 to allow keychain-only team detection.)")
		}
		os.Exit(1)
	}
	
	// Check for preferred team ID match
	for i, id := range teamIDs {
		if id == preferredTeam {
			fmt.Println(id)
			os.Exit(0)
		}
	}
	
	// Check for preferred team name match
	if preferredTeamName != "" {
		preferredTeamNameLC := strings.ToLower(preferredTeamName)
		for i, name := range teamNames {
			if strings.ToLower(name) == preferredTeamNameLC {
				fmt.Println(teamIDs[i])
				os.Exit(0)
			}
		}
	}
	
	// Prefer non-free teams if requested
	if preferNonFreeTeam {
		for i, isFree := range teamIsFree {
			if !isFree {
				fmt.Println(teamIDs[i])
				os.Exit(0)
			}
		}
	}
	
	// Return first team as fallback
	fmt.Println(teamIDs[0])
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func appendTeam(teamIDs *[]string, teamIsFree *[]bool, teamNames *[]string, 
	id string, isFree bool, name string) {
	id = strings.ReplaceAll(id, "\r", "")
	name = strings.ReplaceAll(name, "\r", "")
	
	if id == "" {
		return
	}
	
	// Check if team already exists
	for _, existingID := range *teamIDs {
		if existingID == id {
			return
		}
	}
	
	*teamIDs = append(*teamIDs, id)
	*teamIsFree = append(*teamIsFree, isFree)
	*teamNames = append(*teamNames, name)
}

func loadTeamsFromXcodePreferences(teamIDs, teamIsFree *[]string, teamNames *[]string) {
	home, err := os.UserHomeDir()
	if err != nil {
		return
	}
	
	plistPath := filepath.Join(home, "Library", "Preferences", "com.apple.dt.Xcode.plist")
	if _, err := os.Stat(plistPath); os.IsNotExist(err) {
		return
	}
	
	cmd := exec.Command("plutil", "-extract", "IDEProvisioningTeams", "json", "-o", "-", plistPath)
	output, err := cmd.Output()
	if err != nil {
		return
	}
	
	var data map[string]interface{}
	if err := json.Unmarshal(output, &data); err != nil {
		return
	}
	
	for _, teamsValue := range data {
		if teams, ok := teamsValue.([]interface{}); ok {
			for _, teamValue := range teams {
				if teamMap, ok := teamValue.(map[string]interface{}); ok {
					teamID, _ := teamMap["teamID"].(string)
					teamID = strings.TrimSpace(teamID)
					if teamID == "" {
						continue
					}
					
					isFree := false
					if freeVal, ok := teamMap["isFreeProvisioningTeam"]; ok {
						if freeBool, ok := freeVal.(bool); ok {
							isFree = freeBool
						}
					}
					
					teamName := ""
					if nameVal, ok := teamMap["teamName"]; ok {
						if nameStr, ok := nameVal.(string); ok {
							teamName = strings.ReplaceAll(strings.TrimSpace(nameStr), "\t", " ")
						}
					}
					
					appendTeam(teamIDs, teamIsFree, teamNames, teamID, isFree, teamName)
				}
			}
		}
	}
}

func loadTeamsFromLegacyDefaultsKey(teamIDs, teamIsFree *[]string, teamNames *[]string) {
	cmd := exec.Command("defaults", "read", "com.apple.dt.Xcode", "IDEProvisioningTeamIdentifiers")
	output, err := cmd.Output()
	if err != nil {
		return
	}
	
	re := regexp.MustCompile(`[A-Z0-9]{10}`)
	matches := re.FindAllString(string(output), -1)
	
	for _, match := range matches {
		appendTeam(teamIDs, teamIsFree, teamNames, match, false, "")
	}
}

func loadTeamsFromXcodeManagedProfiles(teamIDs, teamIsFree *[]string, teamNames *[]string) {
	home, err := os.UserHomeDir()
	if err != nil {
		return
	}
	
	profilesDir := filepath.Join(home, "Library", "MobileDevice", "Provisioning Profiles")
	if _, err := os.Stat(profilesDir); os.IsNotExist(err) {
		return
	}
	
	entries, err := os.ReadDir(profilesDir)
	if err != nil {
		return
	}
	
	teamSet := make(map[string]bool)
	
	for _, entry := range entries {
		if !strings.HasSuffix(entry.Name(), ".mobileprovision") {
			continue
		}
		
		profilePath := filepath.Join(profilesDir, entry.Name())
		cmd := exec.Command("security", "cms", "-D", "-i", profilePath)
		output, err := cmd.Output()
		if err != nil {
			continue
		}
		
		// Parse plist manually to extract TeamIdentifier
		lines := strings.Split(string(output), "\n")
		inTeamIdentifier := false
		for _, line := range lines {
			line = strings.TrimSpace(line)
			
			if strings.Contains(line, "<key>TeamIdentifier</key>") {
				inTeamIdentifier = true
				continue
			}
			
			if inTeamIdentifier && strings.HasPrefix(line, "<array>") {
				continue
			}
			
			if inTeamIdentifier && strings.HasPrefix(line, "</array>") {
				inTeamIdentifier = false
				continue
			}
			
			if inTeamIdentifier && strings.HasPrefix(line, "<string>") && strings.HasSuffix(line, "</string>") {
				start := strings.Index(line, "<string>") + 8
				end := strings.Index(line, "</string>")
				if start < end {
					teamID := line[start:end]
					if len(teamID) == 10 && regexp.MustCompile(`^[A-Z0-9]+$`).MatchString(teamID) {
						teamSet[teamID] = true
					}
				}
			}
		}
	}
	
	// Convert set to slice and add teams
	var teams []string
	for team := range teamSet {
		teams = append(teams, team)
	}
	sort.Strings(teams)
	
	for _, team := range teams {
		appendTeam(teamIDs, teamIsFree, teamNames, team, false, "")
	}
}

func loadTeamsFromKeychain(teamIDs, teamIsFree *[]string, teamNames *[]string) {
	cmd := exec.Command("security", "find-identity", "-p", "codesigning", "-v")
	output, err := cmd.Output()
	if err != nil {
		return
	}
	
	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	re := regexp.MustCompile(`\(([A-Z0-9]{10})\)`)
	
	for scanner.Scan() {
		line := scanner.Text()
		matches := re.FindStringSubmatch(line)
		if len(matches) > 1 {
			appendTeam(teamIDs, teamIsFree, teamNames, matches[1], false, "")
		}
	}
}

func hasXcodeAccount() bool {
	home, err := os.UserHomeDir()
	if err != nil {
		return false
	}
	
	plistPath := filepath.Join(home, "Library", "Preferences", "com.apple.dt.Xcode.plist")
	if _, err := os.Stat(plistPath); os.IsNotExist(err) {
		return false
	}
	
	cmd := exec.Command("defaults", "read", "com.apple.dt.Xcode", "DVTDeveloperAccountManagerAppleIDLists")
	output, err := cmd.Output()
	if err != nil {
		return false
	}
	
	outputStr := string(output)
	return outputStr != "" && !strings.Contains(outputStr, "does not exist") && strings.Contains(outputStr, "identifier")
}
