#!/usr/bin/env node
// json_schema_validator.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_schema_validator.py
// auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_schema_validator.py
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

/**
 * JSON Schema Validator - Validiert JSON gegen JSON Schema Draft 7/2020-12.
 * Erweitert Pydantic mit externen Schema-Dateien.
 */

const fs = require('fs');
const path = require('path');

// Dynamically import Ajv for JSON schema validation
let Ajv;
let HAS_AJV = false;
let ajvInstance = null;

try {
  Ajv = require('ajv').default;
  const addFormats = require('ajv-formats').default;
  ajvInstance = new Ajv({ allErrors: true });
  addFormats(ajvInstance);
  HAS_AJV = true;
} catch (error) {
  HAS_AJV = false;
}

// Import custom modules
const { parseJson, JSONProcessingError } = require('./json_processor');

class SchemaValidationError extends Error {
  /** Raised when JSON Schema validation fails. */
  constructor(message) {
    super(message);
    this.name = 'SchemaValidationError';
  }
}

function loadSchema(schemaSource) {
  /**
   * Lädt ein JSON Schema aus verschiedenen Quellen.
   * 
   * @param {string|Object} schemaSource - Pfad zur Schema-Datei oder Schema-Dict oder JSON String
   * @returns {Object} Schema als Dictionary
   */
  if (typeof schemaSource === 'object' && schemaSource !== null) {
    return schemaSource;
  }

  try {
    // Try to read as file path
    if (fs.existsSync(schemaSource)) {
      const content = fs.readFileSync(schemaSource, 'utf8');
      return JSON.parse(content);
    }
  } catch (error) {
    // Not a valid file, continue to next attempt
  }

  // Try to parse as JSON string
  try {
    return JSON.parse(schemaSource);
  } catch (error) {
    throw new SchemaValidationError(`Schema not found or invalid: ${schemaSource}`);
  }
}

function validateWithJsonSchema(data, schema, draft = 'auto') {
  /**
   * Validiert Daten gegen ein JSON Schema.
   * 
   * @param {*} data - Zu validierende Daten
   * @param {string|Object} schema - JSON Schema (Pfad, String oder Dict)
   * @param {string} draft - JSON Schema Draft Version ("auto", "draft7", "2020-12")
   * @returns {boolean} True wenn valid
   * @throws {SchemaValidationError} Wenn Validierung fehlschlägt
   */
  if (!HAS_AJV) {
    throw new SchemaValidationError('ajv not installed. Run: npm install ajv ajv-formats');
  }

  const schemaDict = loadSchema(schema);
  
  try {
    const validate = ajvInstance.compile(schemaDict);
    const valid = validate(data);
    
    if (!valid) {
      const errors = validate.errors.map(err => `${err.instancePath || '/'} ${err.message}`).join(', ');
      throw new SchemaValidationError(`Schema validation failed: ${errors}`);
    }
    
    return true;
  } catch (error) {
    if (error instanceof SchemaValidationError) {
      throw error;
    }
    throw new SchemaValidationError(`Schema validation failed: ${error.message}`);
  }
}

function validateAndConvert(rawInput, schema, repair = true) {
  /**
   * Parst, repariert und validiert JSON gegen Schema.
   * 
   * @param {string} rawInput - JSON-String
   * @param {string|Object} schema - JSON Schema
   * @param {boolean} repair - Ob Reparatur versucht werden soll
   * @returns {*} Validierte Daten
   */
  const data = parseJson(rawInput, repair);
  validateWithJsonSchema(data, schema);
  return data;
}

class SchemaBuilder {
  /** Hilfsklasse zum Erstellen von JSON Schemas. */
  
  static object(properties, required = null) {
    /** Erstellt ein Object-Schema. */
    const schema = {
      type: 'object',
      properties: properties
    };
    if (required) {
      schema.required = required;
    }
    return schema;
  }
  
  static string(enumValues = null, pattern = null, minLength = null) {
    /** Erstellt ein String-Schema. */
    const schema = { type: 'string' };
    if (enumValues) {
      schema.enum = enumValues;
    }
    if (pattern) {
      schema.pattern = pattern;
    }
    if (minLength !== null) {
      schema.minLength = minLength;
    }
    return schema;
  }
  
  static integer(minimum = null, maximum = null) {
    /** Erstellt ein Integer-Schema. */
    const schema = { type: 'integer' };
    if (minimum !== null) {
      schema.minimum = minimum;
    }
    if (maximum !== null) {
      schema.maximum = maximum;
    }
    return schema;
  }
  
  static array(items, minItems = null) {
    /** Erstellt ein Array-Schema. */
    const schema = { type: 'array', items: items };
    if (minItems !== null) {
      schema.minItems = minItems;
    }
    return schema;
  }
}

function main() {
  const { program } = require('commander');
  
  program
    .description('JSON Schema Validator')
    .argument('<input>', 'JSON file or string')
    .option('-s, --schema <schema>', 'Schema file')
    .option('-f, --file', 'Input is file')
    .option('-r, --repair', 'Repair JSON if possible', true)
    .action((input, options) => {
      // Lade Input (Auto-detect file vs string)
      let rawInput;
      
      if (options.file || fs.existsSync(input)) {
        try {
          rawInput = fs.readFileSync(input, 'utf8');
        } catch (error) {
          console.error(`✗ Could not read file: ${error.message}`, file=process.stderr);
          process.exit(1);
        }
      } else {
        rawInput = input;
      }
      
      try {
        const result = validateAndConvert(rawInput, options.schema, options.repair);
        console.log(JSON.stringify(result, null, 2));
        console.error('\n✓ Validation passed');
      } catch (error) {
        if (error instanceof JSONProcessingError || error instanceof SchemaValidationError) {
          console.error(`✗ Validation failed: ${error.message}`);
        } else {
          console.error(`✗ Unexpected error: ${error.message}`);
        }
        process.exit(1);
      }
    });
  
  program.parse();
}

if (require.main === module) {
  main();
}

module.exports = {
  SchemaValidationError,
  loadSchema,
  validateWithJsonSchema,
  validateAndConvert,
  SchemaBuilder
};
