#!/usr/bin/env node
// json_processor.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_processor.py
// auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_processor.py
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

/**
 * JSON Processor mit Validierung und JSON-Reparatur.
 * Für robuste Verarbeitung von LLM-Outputs.
 */

const fs = require('fs');
const path = require('path');

// Zod für Validierung (ersetzt Pydantic)
let zod;
try {
    zod = require('zod');
} catch (e) {
    console.error("Error: zod not installed. Run: npm install zod");
    process.exit(1);
}

// jsonrepair für Reparatur (optional)
let jsonrepair;
try {
    jsonrepair = require('jsonrepair');
} catch (e) {
    console.warn("Warning: jsonrepair not installed. Run: npm install jsonrepair");
}

// Basisklassen für Fehler
class JSONProcessingError extends Error {
    constructor(message) {
        super(message);
        this.name = "JSONProcessingError";
    }
}

class JSONValidationError extends JSONProcessingError {
    constructor(message) {
        super(message);
        this.name = "JSONValidationError";
    }
}

class JSONRepairError extends JSONProcessingError {
    constructor(message) {
        super(message);
        this.name = "JSONRepairError";
    }
}

/**
 * Repariert häufige JSON-Fehler aus LLM-Outputs.
 * 
 * Behebt:
 * - Trailing commas
 * - Einzelne statt doppelte Quotes
 * - JavaScript-Style Kommentare
 * - Unescaped Zeilenumbrüche in Strings
 */
function repairJsonString(rawJson) {
    if (jsonrepair) {
        try {
            return jsonrepair(rawJson);
        } catch (e) {
            throw new JSONRepairError(`JSON repair failed: ${e.message}`);
        }
    } else {
        // Fallback: Manuelle Reparaturen
        let cleaned = rawJson.trim();
        
        // Entferne JavaScript-Kommentare
        cleaned = cleaned.replace(/\/\/.*?\n/g, '\n');
        cleaned = cleaned.replace(/\/\*.*?\*\//gs, '');
        
        // Entferne trailing commas vor ] oder }
        cleaned = cleaned.replace(/,(\s*[}\]])/g, '$1');
        
        return cleaned;
    }
}

/**
 * Parst JSON-String mit optionaler automatischer Reparatur.
 * 
 * @param {string} rawInput - Der zu parsende JSON-String
 * @param {boolean} repair - Ob JSON-Reparatur versucht werden soll (default: true)
 * @returns {any} Geparstes JavaScript-Objekt
 * @throws {JSONProcessingError} Wenn Parsing fehlschlägt
 */
function parseJson(rawInput, repair = true) {
    rawInput = rawInput.trim();
    
    // Versuche zuerst direktes Parsing
    try {
        return JSON.parse(rawInput);
    } catch (e) {
        // Ignoriere Fehler und fahre mit weiteren Versuchen fort
    }
    
    // Extrahiere JSON aus Markdown-Code-Blöcken
    if (rawInput.includes("```")) {
        const patterns = [
            /```json\s*(.*?)\s*```/gs,
            /```\s*(\{.*?\})\s*```/gs,
            /```\s*(\[.*?\])\s*```/gs,
        ];
        
        for (const pattern of patterns) {
            const matches = rawInput.matchAll(pattern);
            for (const match of matches) {
                try {
                    return JSON.parse(match[1]);
                } catch (e) {
                    continue;
                }
            }
        }
    }
    
    // Versuche Reparatur
    if (repair) {
        try {
            const repaired = repairJsonString(rawInput);
            return JSON.parse(repaired);
        } catch (e) {
            throw new JSONProcessingError(`Could not parse JSON even after repair: ${e.message}`);
        }
    }
    
    throw new JSONProcessingError("Could not parse JSON");
}

/**
 * Parst JSON und validiert gegen ein Zod-Schema.
 * 
 * @param {string} rawInput - Der zu parsende JSON-String
 * @param {zod.ZodSchema} schema - Zod-Schema für Validierung
 * @param {boolean} repair - Ob JSON-Reparatur versucht werden soll
 * @returns {any} Validiertes JavaScript-Objekt
 * @throws {JSONValidationError} Wenn Validierung fehlschlägt
 */
function parseAndValidate(rawInput, schema, repair = true) {
    let data;
    try {
        data = parseJson(rawInput, repair);
    } catch (e) {
        throw new JSONValidationError(`JSON parsing failed: ${e.message}`);
    }
    
    try {
        return schema.parse(data);
    } catch (e) {
        throw new JSONValidationError(`Zod validation failed: ${e.errors}`);
    }
}

/**
 * Validiert einen OpenClaw/Tool-Call JSON.
 * 
 * @param {string} rawJson - Der Tool-Call JSON-String
 * @param {string|null} toolName - Optionaler erwarteter Tool-Name
 * @returns {Object} Validiertes Tool-Call Dict
 */
function validateToolCall(rawJson, toolName = null) {
    const { z } = zod;
    
    const ToolCallSchema = z.object({
        tool: z.string().describe("Name of the tool to call"),
        arguments: z.record(z.any()).optional().describe("Tool arguments").default({}),
        reasoning: z.string().optional().describe("Optional reasoning")
    });
    
    const toolCall = parseAndValidate(rawJson, ToolCallSchema, true);
    
    if (toolName && toolCall.tool !== toolName) {
        throw new JSONValidationError(
            `Expected tool '${toolName}', got '${toolCall.tool}'`
        );
    }
    
    return {
        tool: toolCall.tool,
        arguments: toolCall.arguments || {},
        reasoning: toolCall.reasoning
    };
}

/**
 * Sicheres JSON-Parsing mit Fallback auf Default-Wert.
 * 
 * @param {string} rawInput - Der zu parsende JSON-String
 * @param {any} defaultValue - Rückgabewert bei Fehlschlag (default: null)
 * @param {boolean} repair - Ob Reparatur versucht werden soll
 * @returns {any} Geparstes Objekt oder Default-Wert
 */
function safeJsonLoads(rawInput, defaultValue = null, repair = true) {
    try {
        return parseJson(rawInput, repair);
    } catch (e) {
        return defaultValue;
    }
}

/**
 * Extrahiert alle JSON-Objekte aus einem Text.
 * 
 * @param {string} text - Text, der JSON-Objekte enthalten könnte
 * @returns {Array} Liste aller gefundenen und geparsten JSON-Objekte
 */
function extractJsonFromText(text) {
    const results = [];
    
    // Pattern für JSON-Objekte und Arrays
    const patterns = [
        /\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}/g,  // Objekte
        /\[[^\[\]]*(?:\[[^\[\]]*\][^\[\]]*)*\]/g,  // Arrays
    ];
    
    for (const pattern of patterns) {
        const matches = text.match(pattern) || [];
        for (const match of matches) {
            try {
                const parsed = parseJson(match, true);
                results.push(parsed);
            } catch (e) {
                continue;
            }
        }
    }
    
    return results;
}

// CLI-Interface
if (require.main === module) {
    const args = process.argv.slice(2);
    let inputFile = null;
    let isFile = false;
    let repair = true;
    let pretty = false;
    
    // Einfacher Arg-Parser
    for (let i = 0; i < args.length; i++) {
        const arg = args[i];
        if (arg === "--file" || arg === "-f") {
            isFile = true;
        } else if (arg === "--no-repair") {
            repair = false;
        } else if (arg === "--pretty" || arg === "-p") {
            pretty = true;
        } else if (!inputFile) {
            inputFile = arg;
        }
    }
    
    if (!inputFile) {
        console.error("Error: No input provided");
        process.exit(1);
    }
    
    try {
        let content;
        if (isFile) {
            content = fs.readFileSync(inputFile, 'utf8');
        } else {
            content = inputFile;
        }
        
        const result = parseJson(content, repair);
        const output = JSON.stringify(result, null, pretty ? 2 : undefined);
        console.log(output);
    } catch (e) {
        console.error(`Error: ${e.message}`);
        process.exit(1);
    }
}

module.exports = {
    JSONProcessingError,
    JSONValidationError,
    JSONRepairError,
    repairJsonString,
    parseJson,
    parseAndValidate,
    validateToolCall,
    safeJsonLoads,
    extractJsonFromText
};
