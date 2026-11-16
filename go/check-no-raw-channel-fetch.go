// abstraction-provenance: {"artifact_sha256": "71c95903e7ead66a0b686977395eb2d2e000f8af10b6481b807f760aaf1e035e", "source_sha256": "e3a70dc12204181e113d6bd10329e4a0d699a4c3922e73906b5348e1fc3fd07a", "target_language": "go"}
// check-no-raw-channel-fetch.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-raw-channel-fetch.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io/fs"
	"path/filepath"
	"strings"
)

var sourceRoots = []string{"src/channels", "src/routing", "src/line", "extensions"}

// Temporary allowlist for legacy callsites. New raw fetch callsites in channel/plugin runtime
// code should be rejected and migrated to fetchWithSsrFGuard/shared channel helpers.
var allowedRawFetchCallsites = map[string]bool{
	bundledPluginCallsite("bluebubbles", "src/test-harness.ts", 128): true,
	bundledPluginCallsite("bluebubbles", "src/types.ts", 181):       true,
	bundledPluginCallsite("browser", "src/browser/cdp.helpers.ts", 268): true,
	bundledPluginCallsite("browser", "src/browser/client-fetch.ts", 192): true,
	bundledPluginCallsite("browser", "src/browser/test-fetch.ts", 24):    true,
	bundledPluginCallsite("browser", "src/browser/test-fetch.ts", 27):    true,
	bundledPluginCallsite("chutes", "models.ts", 535):                     true,
	bundledPluginCallsite("chutes", "models.ts", 542):                     true,
	bundledPluginCallsite("discord", "src/monitor/gateway-plugin.ts", 322): true,
	bundledPluginCallsite("discord", "src/monitor/gateway-plugin.ts", 360): true,
	bundledPluginCallsite("discord", "src/voice-message.ts", 298):          true,
	bundledPluginCallsite("discord", "src/voice-message.ts", 333):          true,
	bundledPluginCallsite("elevenlabs", "speech-provider.ts", 295):         true,
	bundledPluginCallsite("elevenlabs", "tts.ts", 116):                      true,
	bundledPluginCallsite("feishu", "src/monitor.webhook.test-helpers.ts", 25): true,
	bundledPluginCallsite("github-copilot", "login.ts", 48):                 true,
	bundledPluginCallsite("github-copilot", "login.ts", 80):                true,
	bundledPluginCallsite("googlechat", "src/auth.ts", 83):                  true,
	bundledPluginCallsite("huggingface", "models.ts", 142):                  true,
	bundledPluginCallsite("kilocode", "provider-models.ts", 130):            true,
	bundledPluginCallsite("matrix", "src/matrix/sdk/transport.ts", 112):     true,
	bundledPluginCallsite("microsoft-foundry", "onboard.ts", 479):           true,
	bundledPluginCallsite("microsoft", "speech-provider.ts", 132):            true,
	bundledPluginCallsite("minimax", "oauth.ts", 66):                        true,
	bundledPluginCallsite("minimax", "oauth.ts", 107):                       true,
	bundledPluginCallsite("minimax", "tts.ts", 52):                          true,
	bundledPluginCallsite("msteams", "src/graph.ts", 47):                    true,
	bundledPluginCallsite("msteams", "src/sdk.ts", 329):                     true,
	bundledPluginCallsite("msteams", "src/sdk.ts", 370):                     true,
	bundledPluginCallsite("ollama", "src/stream.ts", 649):                   true,
	bundledPluginCallsite("openai", "tts.ts", 133):                         true,
	bundledPluginCallsite("qa-channel", "src/bus-client.ts", 41):            true,
	bundledPluginCallsite("qa-channel", "src/bus-client.ts", 221):          true,
	bundledPluginCallsite("qa-lab", "src/docker-up.runtime.ts", 274):        true,
	bundledPluginCallsite("qa-lab", "src/gateway-child.ts", 489):             true,
	bundledPluginCallsite("qa-lab", "src/suite.ts", 330):                     true,
	bundledPluginCallsite("qa-lab", "src/suite.ts", 341):                     true,
	bundledPluginCallsite("qa-lab", "web/src/app.ts", 15):                    true,
	bundledPluginCallsite("qa-lab", "web/src/app.ts", 23):                   true,
	bundledPluginCallsite("qa-lab", "web/src/app.ts", 31):                   true,
	bundledPluginCallsite("qqbot", "src/api.ts", 102):                       true,
	bundledPluginCallsite("qqbot", "src/api.ts", 237):                       true,
	bundledPluginCallsite("qqbot", "src/stt.ts", 81):                        true,
	bundledPluginCallsite("qqbot", "src/tools/channel.ts", 180):              true,
	bundledPluginCallsite("qqbot", "src/utils/audio-convert.ts", 377):      true,
	bundledPluginCallsite("signal", "src/install-signal-cli.ts", 224):        true,
	bundledPluginCallsite("slack", "src/monitor/media.ts", 96):             true,
	bundledPluginCallsite("slack", "src/monitor/media.ts", 115):            true,
	bundledPluginCallsite("slack", "src/monitor/media.ts", 120):            true,
	bundledPluginCallsite("tlon", "src/tlon-api.ts", 185):                   true,
	bundledPluginCallsite("tlon", "src/tlon-api.ts", 235):                   true,
	bundledPluginCallsite("tlon", "src/tlon-api.ts", 289):                   true,
	bundledPluginCallsite("venice", "models.ts", 552):                       true,
	bundledPluginCallsite("vercel-ai-gateway", "models.ts", 181):             true,
	bundledPluginCallsite("voice-call", "src/providers/twilio/api.ts", 23):  true,
}

func bundledPluginCallsite(plugin string, file string, line int) string {
	return fmt.Sprintf("%s:%s:%d", plugin, file, line)
}

func isRawFetchCall(expr ast.Expr) bool {
	switch e := expr.(type) {
	case *ast.Ident:
		return e.Name == "fetch"
	case *ast.SelectorExpr:
		if ident, ok := e.X.(*ast.Ident); ok {
			return ident.Name == "globalThis" && e.Sel.Name == "fetch"
		}
	}
	return false
}

func findRawFetchCallLines(content string, fileName string) []int {
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, fileName, content, parser.AllErrors)
	if err != nil {
		fmt.Printf("Error parsing file %s: %v\n", fileName, err)
		return nil
	}

	var lines []int
	ast.Inspect(file, func(n ast.Node) bool {
		if call, ok := n.(*ast.CallExpr); ok {
			if isRawFetchCall(call.Fun) {
				pos := fset.Position(call.Pos())
				lines = append(lines, pos.Line)
			}
		}
		return true
	})
	
	return lines
}

func runCallsiteGuard(sourceRoots []string, extraTestSuffixes []string, findCallLines func(string, string) []int, allowCallsite func(string) bool, header string, footer string) {
	fmt.Println(header)
	
	foundIssues := false
	
	for _, root := range sourceRoots {
		err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			
			if d.IsDir() {
				return nil
			}
			
			if !strings.HasSuffix(path, ".ts") {
				return nil
			}
			
			content, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			
			lines := findCallLines(string(content), path)
			for _, line := range lines {
				callsite := fmt.Sprintf("%s:%d", path, line)
				if !allowCallsite(callsite) {
					fmt.Printf("Found raw fetch() at %s\n", callsite)
					foundIssues = true
				}
			}
			
			return nil
		})
		
		if err != nil {
			fmt.Printf("Error walking directory %s: %v\n", root, err)
		}
	}
	
	if foundIssues {
		fmt.Println(footer)
		os.Exit(1)
	}
}

func main() {
	runCallsiteGuard(
		sourceRoots,
		[]string{".browser.test.ts", ".node.test.ts"},
		findRawFetchCallLines,
		func(callsite string) bool {
			return allowedRawFetchCallsites[callsite]
		},
		"Found raw fetch() usage in channel/plugin runtime sources outside allowlist:",
		"Use fetchWithSsrFGuard() or existing channel/plugin SDK wrappers for network calls.",
	)
}
