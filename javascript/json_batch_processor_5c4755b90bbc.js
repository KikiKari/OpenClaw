#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "b3dd5a161f02db656101f2d0c61c672b7e990ff70287d3ebbb729f70f2fd9e90", "source_sha256": "40b902ee3739509c4b2ef72ed57b4d983e5b509f6e446d20ab14d630d9773322", "target_language": "javascript"}
// json_batch_processor.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
// auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

/**
 * Batch JSON Processor - Verarbeitet mehrere JSON-Dateien oder JSON-Lines (NDJSON).
 */

const fs = require('fs');
const path = require('path');
const { Command } = require('commander');

// Versuche Pydantic-ähnliche Validierung zu laden (wird durch eigenes Modul ersetzt)
let HAS_VALIDATION = false;
let parse_json, parse_and_validate, JSONProcessingError;

try {
    // In Node.js muss das entsprechende Modul angepasst werden
    const jsonProcessorModule = require('./json_processor');
    parse_json = jsonProcessorModule.parse_json;
    parse_and_validate = jsonProcessorModule.parse_and_validate;
    JSONProcessingError = jsonProcessorModule.JSONProcessingError;
    HAS_VALIDATION = true;
} catch (e) {
    HAS_VALIDATION = false;
}

class BatchResult {
    /** Ergebnis einer Batch-Verarbeitung. */
    
    constructor(index, source, success, data = null, error = null) {
        this.index = index;
        this.source = source;
        this.success = success;
        this.data = data;
        this.error = error;
    }
    
    toDict() {
        return {
            index: this.index,
            source: this.source,
            success: this.success,
            data: this.data,
            error: this.error
        };
    }
}

function* readJsonl(filePath) {
    /**
     * Liest JSON-Lines (NDJSON) Datei Zeile für Zeile.
     * 
     * @param {string} filePath - Pfad zur .jsonl oder .ndjson Datei
     * @yields {Object|BatchResult} - Geparste JSON-Objekte oder Fehler
     */
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    
    for (let i = 0; i < lines.length; i++) {
        const lineNum = i + 1;
        let line = lines[i].trim();
        if (!line) continue;
        
        try {
            yield JSON.parse(line);
        } catch (e) {
            yield new BatchResult(
                lineNum,
                `${filePath}:${lineNum}`,
                false,
                null,
                `JSON decode error: ${e.message}`
            );
        }
    }
}

async function processBatch(inputs, processor, maxWorkers = 4) {
    /**
     * Verarbeitet eine Liste von Inputs parallel.
     * 
     * @param {Array} inputs - Liste der zu verarbeitenden Eingaben (Strings oder Pfade)
     * @param {Function} processor - Funktion, die (input, index) => Promise<BatchResult> zurückgibt
     * @param {number} maxWorkers - Anzahl paralleler Worker
     * @returns {Promise<Array>} - Liste der BatchResult-Objekte
     */
    const results = [];
    const workerPromises = [];
    
    // Erstelle Worker-Pool
    for (let idx = 0; idx < inputs.length; idx++) {
        const inp = inputs[idx];
        const promise = processor(inp, idx).then(result => ({ result, idx }));
        workerPromises.push(promise);
        
        // Begrenze gleichzeitige Promises
        if (workerPromises.length >= maxWorkers) {
            const { result, idx } = await Promise.race(workerPromises);
            results.push({ result, idx });
            workerPromises.splice(workerPromises.indexOf(Promise.resolve({ result, idx })), 1);
        }
    }
    
    // Warte auf alle verbleibenden Promises
    const remainingResults = await Promise.all(workerPromises);
    remainingResults.forEach(({ result, idx }) => {
        results.push({ result, idx });
    });
    
    // Sortiere nach Index
    results.sort((a, b) => a.idx - b.idx);
    return results.map(r => r.result);
}

async function processFileBatch(filePaths, repair = true, validateModel = null, maxWorkers = 4) {
    /**
     * Verarbeitet mehrere JSON-Dateien im Batch.
     * 
     * @param {Array<string>} filePaths - Liste der Datei-Pfade
     * @param {boolean} repair - Ob JSON-Reparatur angewendet werden soll
     * @param {Function|null} validateModel - Optionale Validierungsfunktion
     * @param {number} maxWorkers - Parallele Worker
     * @returns {Promise<Array>} - Liste der BatchResult-Objekte
     */
    const processor = async (filePath, idx) => {
        try {
            const content = fs.readFileSync(filePath, 'utf8');
            
            let data;
            if (validateModel && HAS_VALIDATION) {
                data = parse_and_validate(content, validateModel, repair);
            } else {
                data = parse_json(content, repair);
            }
            
            return new BatchResult(idx, filePath, true, data);
        } catch (e) {
            if (e instanceof JSONProcessingError) {
                return new BatchResult(idx, filePath, false, null, e.message);
            } else {
                return new BatchResult(idx, filePath, false, null, `${e.constructor.name}: ${e.message}`);
            }
        }
    };
    
    return await processBatch(filePaths, processor, maxWorkers);
}

function processJsonlFile(filePath, repair = true, validateModel = null) {
    /**
     * Verarbeitet eine JSON-Lines Datei.
     * 
     * @param {string} filePath - Pfad zur .jsonl Datei
     * @param {boolean} repair - Ob Reparatur angewendet werden soll
     * @param {Function|null} validateModel - Optionale Validierungsfunktion
     * @returns {Array} - Liste der BatchResult-Objekte
     */
    const results = [];
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    
    for (let lineNum = 0; lineNum < lines.length; lineNum++) {
        const actualLineNum = lineNum + 1;
        let line = lines[lineNum].trim();
        if (!line) continue;
        
        try {
            let data;
            if (validateModel && HAS_VALIDATION) {
                data = parse_and_validate(line, validateModel, repair);
            } else {
                data = parse_json(line, repair);
            }
            
            results.push(new BatchResult(
                actualLineNum,
                `${filePath}:${actualLineNum}`,
                true,
                data
            ));
        } catch (e) {
            if (e instanceof JSONProcessingError) {
                results.push(new BatchResult(
                    actualLineNum,
                    `${filePath}:${actualLineNum}`,
                    false,
                    null,
                    e.message
                ));
            }
        }
    }
    
    return results;
}

function writeJsonl(results, outputPath, onlySuccessful = true) {
    /**
     * Schreibt BatchResult-Liste als JSON-Lines.
     * 
     * @param {Array} results - Liste der Ergebnisse
     * @param {string} outputPath - Ausgabedatei
     * @param {boolean} onlySuccessful - Nur erfolgreiche Ergebnisse schreiben
     */
    const fd = fs.openSync(outputPath, 'w');
    
    for (const result of results) {
        if (onlySuccessful && !result.success) continue;
        const jsonLine = JSON.stringify(result.toDict()) + '\n';
        fs.writeFileSync(fd, jsonLine, 'utf8');
    }
    
    fs.closeSync(fd);
}

async function main() {
    const program = new Command();
    
    program
        .description("Batch JSON Processor")
        .argument("<inputs...>", "JSON files to process")
        .option("--jsonl, -l", "Treat inputs as JSON-Lines files")
        .option("--repair, -r", "Enable JSON repair", true)
        .option("--workers, -w <number>", "Parallel workers", "4")
        .option("--output, -o <file>", "Output JSON-Lines file")
        .option("--summary, -s", "Show summary only")
        .action(async (inputs, options) => {
            let allResults = [];
            
            if (options.jsonl) {
                // JSON-Lines Modus
                for (const inputPath of inputs) {
                    const results = processJsonlFile(inputPath, options.repair);
                    allResults = allResults.concat(results);
                }
            } else {
                // Standard JSON Batch
                const filePaths = inputs.map(p => path.resolve(p));
                allResults = await processFileBatch(
                    filePaths,
                    options.repair,
                    null,
                    parseInt(options.workers)
                );
            }
            
            // Ausgabe
            const successful = allResults.filter(r => r.success).length;
            const failed = allResults.length - successful;
            
            if (options.summary) {
                console.log(`Processed: ${allResults.length}`);
                console.log(`Successful: ${successful}`);
                console.log(`Failed: ${failed}`);
            } else {
                for (const result of allResults) {
                    if (result.success) {
                        console.log(JSON.stringify(result.data));
                    } else {
                        console.error(`ERROR [${result.source}]: ${result.error}`);
                    }
                }
            }
            
            // Optional: JSONL Output
            if (options.output) {
                writeJsonl(allResults, options.output, false);
                console.error(`\nResults written to: ${options.output}`);
            }
            
            // Exit code
            process.exit(failed === 0 ? 0 : 1);
        });
    
    await program.parseAsync(process.argv);
}

if (require.main === module) {
    main().catch(console.error);
}
