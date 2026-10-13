#!/usr/bin/env node
// validate_tool_output.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/validate_tool_output.py
// auch in: OpenClaw@gateway2:skills/json-utils/scripts/validate_tool_output.py
// Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

/**
 * Validiert Tool-Outputs gegen ein Pydantic-Schema.
 * Für OpenClaw Tool-Call-Validierung.
 */

const fs = require('fs');
const path = require('path');
const process = require('process');

// Zod für Schema-Validierung (ersetzt Pydantic)
let z;
try {
    z = require('zod');
} catch (e) {
    console.error("Error: zod not installed");
    process.exit(1);
}

// minimist für Argumentenverarbeitung
let minimist;
try {
    minimist = require('minimist');
} catch (e) {
    // Fallback ohne externe Abhängigkeit
    minimist = (args) => {
        const result = { _: [] };
        for (let i = 0; i < args.length; i++) {
            const arg = args[i];
            if (arg.startsWith('--')) {
                const key = arg.slice(2);
                const next = args[i + 1];
                if (next && !next.startsWith('-')) {
                    if (key === 'schema' || key === 's') {
                        result.schema = next;
                    } else if (key === 'file' || key === 'f') {
                        result.file = true;
                    } else if (key === 'repair' || key === 'r') {
                        result.repair = true;
                    } else if (key === 'strict') {
                        result.strict = true;
                    }
                    i++;
                } else {
                    if (key === 'file' || key === 'f' || key === 'repair' || key === 'r' || key === 'strict') {
                        result[key] = true;
                    }
                }
            } else if (arg.startsWith('-')) {
                const keys = arg.slice(1);
                for (const k of keys) {
                    if (k === 'f') result.file = true;
                    if (k === 'r') result.repair = true;
                    if (k === 's') {
                        const next = args[i + 1];
                        if (next && !next.startsWith('-')) {
                            result.schema = next;
                            i++;
                        }
                    }
                }
            } else {
                result._.push(arg);
            }
        }
        return result;
    };
}

class JSONValidationError extends Error {
    constructor(message) {
        super(message);
        this.name = "JSONValidationError";
    }
}

function parseAndValidate(jsonInput, schema, options = {}) {
    const { repair = true, strict = false } = options;
    
    let data;
    try {
        data = typeof jsonInput === 'string' ? JSON.parse(jsonInput) : jsonInput;
    } catch (e) {
        throw new JSONValidationError(`Invalid JSON: ${e.message}`);
    }
    
    try {
        const result = schema.parse(data);
        return result;
    } catch (error) {
        if (repair && !strict) {
            // Versuche partielle Reparatur
            const partialData = {};
            const shape = schema.shape || {};
            
            for (const key in data) {
                if (key in shape) {
                    try {
                        partialData[key] = shape[key].parse(data[key]);
                    } catch (e) {
                        // Überspringe ungültige Felder im Reparaturmodus
                    }
                } else if (!strict) {
                    // Übernehme unbekannte Felder im nicht-strikten Modus
                    partialData[key] = data[key];
                }
            }
            
            try {
                const repairedResult = schema.parse(partialData);
                return repairedResult;
            } catch (repairedError) {
                throw new JSONValidationError(`Validation failed even after repair: ${error.message}`);
            }
        } else {
            throw new JSONValidationError(`Validation failed: ${error.message}`);
        }
    }
}

function createDynamicModel(schema) {
    /** Erstellt ein dynamisches Zod-Schema aus einem JSON-Schema. */
    const properties = schema.properties || {};
    const requiredFields = schema.required || [];
    
    const shape = {};
    
    for (const [fieldName, fieldInfo] of Object.entries(properties)) {
        let fieldSchema = z.string(); // Default
        
        const jsonType = fieldInfo.type || "string";
        switch (jsonType) {
            case "integer":
                fieldSchema = z.number().int();
                break;
            case "number":
                fieldSchema = z.number();
                break;
            case "boolean":
                fieldSchema = z.boolean();
                break;
            case "array":
                fieldSchema = z.array(z.any());
                break;
            case "object":
                fieldSchema = z.record(z.any());
                break;
            default:
                fieldSchema = z.string();
        }
        
        // Optionale Felder
        if (!requiredFields.includes(fieldName)) {
            fieldSchema = fieldSchema.optional();
            if ('default' in fieldInfo) {
                fieldSchema = fieldSchema.default(fieldInfo.default);
            }
        }
        
        shape[fieldName] = fieldSchema;
    }
    
    return z.object(shape);
}

function main() {
    const argv = process.argv.slice(2);
    const args = minimist(argv, {
        alias: {
            s: 'schema',
            f: 'file',
            r: 'repair'
        },
        boolean: ['file', 'repair', 'strict'],
        default: {
            repair: true
        }
    });
    
    if (!args.schema) {
        console.error("Error: --schema/-s is required");
        process.exit(1);
    }
    
    const jsonInputArg = args._[0];
    if (!jsonInputArg) {
        console.error("Error: json_input argument is required");
        process.exit(1);
    }
    
    // Lade Schema
    let schema;
    try {
        const schemaContent = fs.readFileSync(path.resolve(args.schema), 'utf8');
        schema = JSON.parse(schemaContent);
    } catch (e) {
        console.error(`Error loading schema: ${e.message}`);
        process.exit(1);
    }
    
    // Lade Input
    let rawInput;
    try {
        if (args.file) {
            rawInput = fs.readFileSync(path.resolve(jsonInputArg), 'utf8');
        } else {
            rawInput = jsonInputArg;
        }
    } catch (e) {
        console.error(`Error loading input: ${e.message}`);
        process.exit(1);
    }
    
    // Erstelle dynamisches Modell und validiere
    try {
        const modelSchema = createDynamicModel(schema);
        const result = parseAndValidate(rawInput, modelSchema, { 
            repair: args.repair, 
            strict: args.strict 
        });
        
        console.log(JSON.stringify(result, null, 2));
    } catch (e) {
        if (e instanceof JSONValidationError) {
            console.error(`Validation error: ${e.message}`);
        } else {
            console.error(`Unexpected error: ${e.message}`);
        }
        process.exit(1);
    }
}

main();
