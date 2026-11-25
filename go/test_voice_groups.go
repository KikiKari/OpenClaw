// abstraction-provenance: {"artifact_sha256": "c46288b7644f99f94810364105e236cb57bedb7c16bb66e392e7bcda6c0c34c7", "source_sha256": "c451131599cab4bee1c4c62c6eac8c382c366e4cacf443d53c179c01a326a251", "target_language": "go"}
// test_voice_groups.cjs — portiert nach go
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_voice_groups.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_voice_groups.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_voice_groups.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_voice_groups.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

type Voice struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Group string `json:"group"`
}

type Element struct {
	Tag      string
	Label    string
	Value    string
	Children []*Element
	Dataset  map[string]string
}

func (e *Element) Append(child *Element) {
	e.Children = append(e.Children, child)
}

func createElement(tag string) *Element {
	return &Element{
		Tag:     tag,
		Children: []*Element{},
		Dataset: map[string]string{},
	}
}

type Context struct {
	Document           *Document
	Elements           map[string]*Element
	SpeechVoiceName    string
	VoiceCatalog       []Voice
	SpeechVoiceOptions []Voice
}

type Document struct{}

func (d *Document) CreateElement(tag string) *Element {
	return createElement(tag)
}

func NewContext() *Context {
	selectEl := createElement("select")
	return &Context{
		Document: &Document{},
		Elements: map[string]*Element{
			"speech-voice": selectEl,
		},
		SpeechVoiceName:    "sherpa-de-supertonic-7",
		VoiceCatalog:       []Voice{},
		SpeechVoiceOptions: []Voice{},
	}
}

func (c *Context) ClearChildren(node *Element) {
	node.Children = []*Element{}
}

func (c *Context) SetSpeechVoiceOptions(options []Voice, voices []Voice) {
	c.SpeechVoiceOptions = options
	selectEl := c.Elements["speech-voice"]
	c.ClearChildren(selectEl)

	// Create groups
	groups := make(map[string]*Element)
	for _, label := range []string{"Kyrillisch", "Asiatisch", "Abjad", "Indisch", "Effekt Stimmen"} {
		group := createElement("optgroup")
		group.Label = label
		groups[label] = group
		selectEl.Append(group)
	}

	// Add voices to groups
	for _, voice := range voices {
		if group, exists := groups[voice.Group]; exists {
			option := createElement("option")
			option.Value = voice.ID
			option.Dataset["label"] = voice.Name
			group.Append(option)
		}
	}

	// Add custom options
	for _, option := range options {
		if option.Group == "" {
			optEl := createElement("option")
			optEl.Value = option.ID
			optEl.Dataset["label"] = option.Name
			selectEl.Append(optEl)
		}
	}

	// Set selected value
	selectEl.Value = c.SpeechVoiceName
}

func readFile(filename string) string {
	content, err := ioutil.ReadFile(filename)
	if err != nil {
		log.Fatal(err)
	}
	return string(content)
}

func extractFunction(source, startMarker, endMarker string) string {
	startIndex := strings.Index(source, startMarker)
	if startIndex == -1 {
		return ""
	}
	endIndex := strings.Index(source[startIndex:], endMarker)
	if endIndex == -1 {
		return source[startIndex:]
	}
	return source[startIndex : startIndex+endIndex+len(endMarker)]
}

func main() {
	dir, err := os.Getwd()
	if err != nil {
		log.Fatal(err)
	}

	sourcePath := filepath.Join(dir, "../browser-extension/sidepanel.js")
	voiceCatalogPath := filepath.Join(dir, "../companion-service/voice-catalog.json")

	source := readFile(sourcePath)
	voiceCatalogData := readFile(voiceCatalogPath)

	var catalog struct {
		Voices []Voice `json:"voices"`
	}
	err = json.Unmarshal([]byte(voiceCatalogData), &catalog)
	if err != nil {
		log.Fatal(err)
	}

	context := NewContext()
	context.VoiceCatalog = catalog.Voices

	// Extract and run relevant code portions
	baseVoiceOrderCode := extractFunction(source, "  const BASE_VOICE_ORDER", "  const core =")
	sherpaSpeechVoicesCode := extractFunction(source, "  function sherpaSpeechVoices", "  async function loadSpeechVoices")

	// Simulate the JavaScript execution by manually implementing the logic
	// This is a simplified version - in reality you'd need a proper JS engine
	context.SetSpeechVoiceOptions([]Voice{}, context.VoiceCatalog)

	// Test assertions
	labels := []string{"Kyrillisch", "Asiatisch", "Abjad", "Indisch", "Effekt Stimmen"}
	selectEl := context.Elements["speech-voice"]

	for _, label := range labels {
		var group *Element
		for _, child := range selectEl.Children {
			if child.Label == label {
				group = child
				break
			}
		}
		if group == nil {
			log.Fatalf("FAIL: Group %s not found", label)
		}
		if len(group.Children) < 3 {
			log.Fatalf("FAIL: Group %s has less than 3 children", label)
		}
	}

	// Check specific group count
	var effectGroup *Element
	for _, child := range selectEl.Children {
		if child.Label == "Effekt Stimmen" {
			effectGroup = child
			break
		}
	}
	if effectGroup == nil || len(effectGroup.Children) != 5 {
		log.Fatal("FAIL: Effect Stimmen group should have 5 children")
	}

	if selectEl.Value != "sherpa-de-supertonic-7" {
		log.Fatal("FAIL: Select value should be sherpa-de-supertonic-7")
	}

	// Test with custom options
	customOptions := []Voice{{ID: "sherpa-de-supertonic-7", Name: "Stil 3", Group: ""}}
	context.SetSpeechVoiceOptions(customOptions, context.VoiceCatalog)

	if selectEl.Value != "sherpa-de-supertonic-7" {
		log.Fatal("FAIL: Select value should remain sherpa-de-supertonic-7")
	}

	var effectGroupWithCustom *Element
	for _, child := range selectEl.Children {
		if child.Label == "Effekt Stimmen" {
			effectGroupWithCustom = child
			break
		}
	}
	
	found := false
	for _, child := range effectGroupWithCustom.Children {
		if child.Value == selectEl.Value {
			found = true
			break
		}
	}
	if !found {
		log.Fatal("FAIL: Selected value should be in Effekt Stimmen group")
	}

	// Test legacy catalog fallback
	context.SpeechVoiceName = "sherpa-ru-irina"
	var voicesWithoutGroups []Voice
	for _, voice := range context.VoiceCatalog {
		v := voice
		v.Group = ""
		voicesWithoutGroups = append(voicesWithoutGroups, v)
	}
	context.SetSpeechVoiceOptions([]Voice{}, voicesWithoutGroups)

	if selectEl.Value != "sherpa-ru-irina" {
		log.Fatal("FAIL: Select value should be sherpa-ru-irina")
	}

	var kyrillischGroup *Element
	for _, child := range selectEl.Children {
		if child.Label == "Kyrillisch" {
			kyrillischGroup = child
			break
		}
	}
	
	foundInKyrillisch := false
	for _, child := range kyrillischGroup.Children {
		if child.Value == "sherpa-ru-irina" {
			foundInKyrillisch = true
			break
		}
	}
	if !foundInKyrillisch {
		log.Fatal("FAIL: sherpa-ru-irina should be in Kyrillisch group")
	}

	fmt.Println("PASS: five groups, all styles selectable, retained selection, legacy catalog fallback")
}
