// abstraction-provenance: {"artifact_sha256": "9445b1aa4e77a94b2b5f61f2a1efc76bf86a79b4a73c8cf29dc94c0acb0760d8", "source_sha256": "a1a384d35f3380f69c57a009348f8a076cc5e3fc09ba866cde4cf59a1c6ac88b", "target_language": "go"}
// arg-utils.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/arg-utils.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

func readEnvNumber(name string, env map[string]string) *float64 {
	raw, exists := env[name]
	if !exists {
		return nil
	}
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	parsed, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		return nil
	}
	return &parsed
}

func consumeStringFlag(argv []string, index int, flag string, currentValue string) *struct {
	nextIndex int
	value     string
} {
	if index >= len(argv) || argv[index] != flag {
		return nil
	}
	result := struct {
		nextIndex int
		value     string
	}{nextIndex: index + 1}
	if index+1 < len(argv) {
		result.value = argv[index+1]
	} else {
		result.value = currentValue
	}
	return &result
}

func consumeStringListFlag(argv []string, index int, flag string) *struct {
	nextIndex int
	value     *string
} {
	if index >= len(argv) || argv[index] != flag {
		return nil
	}
	result := struct {
		nextIndex int
		value     *string
	}{nextIndex: index + 1}
	if index+1 < len(argv) && argv[index+1] != "" {
		result.value = &argv[index+1]
	} else {
		result.value = nil
	}
	return &result
}

func consumeIntFlag(argv []string, index int, flag string, currentValue int, options map[string]interface{}) *struct {
	nextIndex int
	value     int
} {
	if index >= len(argv) || argv[index] != flag {
		return nil
	}
	var min float64 = -float64(^uint(0) >> 1) // Negative infinity approximation
	if val, ok := options["min"]; ok {
		min = val.(float64)
	}
	var raw string
	if index+1 < len(argv) {
		raw = argv[index+1]
	}
	parsed, err := strconv.Atoi(raw)
	if err != nil {
		return &struct {
			nextIndex int
			value     int
		}{nextIndex: index + 1, value: currentValue}
	}
	if float64(parsed) >= min {
		return &struct {
			nextIndex int
			value     int
		}{nextIndex: index + 1, value: parsed}
	}
	return &struct {
		nextIndex int
		value     int
	}{nextIndex: index + 1, value: currentValue}
}

func consumeFloatFlag(argv []string, index int, flag string, currentValue float64, options map[string]interface{}) *struct {
	nextIndex int
	value     float64
} {
	if index >= len(argv) || argv[index] != flag {
		return nil
	}
	var min float64 = -float64(^uint(0) >> 1) // Negative infinity approximation
	if val, ok := options["min"]; ok {
		min = val.(float64)
	}
	includeMin := true
	if val, ok := options["includeMin"]; ok {
		includeMin = val.(bool)
	}
	var raw string
	if index+1 < len(argv) {
		raw = argv[index+1]
	}
	parsed, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		return &struct {
			nextIndex int
			value     float64
		}{nextIndex: index + 1, value: currentValue}
	}
	isValid := !isNaN(parsed) && (includeMin && parsed >= min || !includeMin && parsed > min)
	if isValid {
		return &struct {
			nextIndex int
			value     float64
		}{nextIndex: index + 1, value: parsed}
	}
	return &struct {
		nextIndex int
		value     float64
	}{nextIndex: index + 1, value: currentValue}
}

func isNaN(f float64) bool {
	return f != f
}

func stringFlag(flag string, key string) map[string]interface{} {
	return map[string]interface{}{
		"consume": func(argv []string, index int, args map[string]interface{}) interface{} {
			currentValue := ""
			if val, ok := args[key]; ok {
				currentValue = val.(string)
			}
			option := consumeStringFlag(argv, index, flag, currentValue)
			if option == nil {
				return nil
			}
			return map[string]interface{}{
				"nextIndex": option.nextIndex,
				"apply": func(target map[string]interface{}) {
					target[key] = option.value
				},
			}
		},
	}
}

func stringListFlag(flag string, key string) map[string]interface{} {
	return map[string]interface{}{
		"consume": func(argv []string, index int, args map[string]interface{}) interface{} {
			option := consumeStringListFlag(argv, index, flag)
			if option == nil {
				return nil
			}
			return map[string]interface{}{
				"nextIndex": option.nextIndex,
				"apply": func(target map[string]interface{}) {
					if option.value != nil {
						if list, ok := target[key].([]string); ok {
							target[key] = append(list, *option.value)
						} else {
							target[key] = []string{*option.value}
						}
					}
				},
			}
		},
	}
}

func createAssignedValueFlag(consumeOption func([]string, int, map[string]interface{}) interface{}) map[string]interface{} {
	return map[string]interface{}{
		"consume": func(argv []string, index int, args map[string]interface{}) interface{} {
			option := consumeOption(argv, index, args)
			if option == nil {
				return nil
			}
			return map[string]interface{}{
				"nextIndex": option.(map[string]interface{})["nextIndex"],
				"apply": func(target map[string]interface{}) {
					if optMap, ok := option.(map[string]interface{}); ok {
						if key, ok := optMap["key"].(string); ok {
							if value, ok := optMap["value"]; ok {
								target[key] = value
							}
						}
					}
				},
			}
		},
	}
}

func intFlag(flag string, key string, options map[string]interface{}) map[string]interface{} {
	consumeFunc := func(argv []string, index int, args map[string]interface{}) interface{} {
		currentValue := 0
		if val, ok := args[key]; ok {
			currentValue = val.(int)
		}
		option := consumeIntFlag(argv, index, flag, currentValue, options)
		if option == nil {
			return nil
		}
		return map[string]interface{}{
			"nextIndex": option.nextIndex,
			"value":     option.value,
			"key":       key,
		}
	}
	return createAssignedValueFlag(consumeFunc)
}

func floatFlag(flag string, key string, options map[string]interface{}) map[string]interface{} {
	consumeFunc := func(argv []string, index int, args map[string]interface{}) interface{} {
		currentValue := 0.0
		if val, ok := args[key]; ok {
			currentValue = val.(float64)
		}
		option := consumeFloatFlag(argv, index, flag, currentValue, options)
		if option == nil {
			return nil
		}
		return map[string]interface{}{
			"nextIndex": option.nextIndex,
			"value":     option.value,
			"key":       key,
		}
	}
	return createAssignedValueFlag(consumeFunc)
}

func booleanFlag(flag string, key string, value bool) map[string]interface{} {
	return map[string]interface{}{
		"consume": func(argv []string, index int, args map[string]interface{}) interface{} {
			if index >= len(argv) || argv[index] != flag {
				return nil
			}
			return map[string]interface{}{
				"nextIndex": index,
				"apply": func(target map[string]interface{}) {
					target[key] = value
				},
			}
		},
	}
}

func parseFlagArgs(argv []string, args map[string]interface{}, specs []map[string]interface{}, options map[string]interface{}) map[string]interface{} {
	allowUnknownOptions := false
	if val, ok := options["allowUnknownOptions"]; ok {
		allowUnknownOptions = val.(bool)
	}
	ignoreDoubleDash := false
	if val, ok := options["ignoreDoubleDash"]; ok {
		ignoreDoubleDash = val.(bool)
	}
	
	for i := 0; i < len(argv); i++ {
		arg := argv[i]
		if arg == "--" && ignoreDoubleDash {
			continue
		}
		handled := false
		for _, spec := range specs {
			if consumeFunc, ok := spec["consume"].(func([]string, int, map[string]interface{}) interface{}); ok {
				option := consumeFunc(argv, i, args)
				if option == nil {
					continue
				}
				if optMap, ok := option.(map[string]interface{}); ok {
					if applyFunc, ok := optMap["apply"].(func(map[string]interface{})); ok {
						applyFunc(args)
					}
					if nextIdx, ok := optMap["nextIndex"].(int); ok {
						i = nextIdx
					}
				}
				handled = true
				break
			}
		}
		if handled {
			continue
		}
		if onUnhandledArg, ok := options["onUnhandledArg"].(func(string, map[string]interface{}) string); ok {
			fallbackResult := onUnhandledArg(arg, args)
			if fallbackResult == "handled" {
				continue
			}
		}
		if !allowUnknownOptions && strings.HasPrefix(arg, "-") {
			panic(fmt.Sprintf("Unknown option: %s", arg))
		}
	}
	return args
}

func main() {
	// Example usage would go here
}
