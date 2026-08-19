#!/usr/bin/env node
// json_batch_processor.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
// auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

/**
 * Batch JSON Processor - Verarbeitet mehrere JSON-Dateien oder JSON-Lines (NDJSON).
 */

const fs = require('fs');
const path = require('path');
const { program } = require('commander');

// Simuliere einige Python-ähnliche Funktionen
function* readJsonl(filePath) {
    /**
     * Liest JSON-Lines (NDJSON) Datei Zeile für Zeile.
     *
     * @param {string} filePath - Pfad zur .jsonl oder .ndjson Datei
     * @yields {Object|BatchResult} - Geparste JSON-Objekte oder Fehler
     */
    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.split('\n');
    
    for (let lineNum = 0; lineNum < lines.length; lineNum++) {
        const line = lines[lineNum].trim();
        if (!line) continue;
        
        try {
            yield JSON.parse(line);
        } catch (e) {
            yield new BatchResult(
                lineNum + 1,
                `${filePath}:${lineNum + 1}`,
                false,
                null,
                `JSON decode error: ${e.message}`
            );
        }
    }
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

class JSONProcessingError extends Error {
    constructor(message) {
        super(message);
        this.name = 'JSONProcessingError';
    }
}

function parseJson(content, repair = true) {
    /**
     * Parst JSON-Inhalt mit optionaler Reparatur.
     * 
     * @param {string} content - JSON-String
     * @param {boolean} repair - Ob Reparatur versucht werden soll
     * @returns {Object} - Geparstes JSON
     */
    try {
        return JSON.parse(content);
    } catch (e) {
        if (repair) {
            // Versuche einfache Reparaturen
            let repaired = content.replace(/,\s*}/g, '}').replace(/,\s*\]/g, ']');
            try {
                return JSON.parse(repaired);
            } catch (repairError) {
                throw new JSONProcessingError(`JSON parsing failed: ${e.message}`);
            }
        } else {
            throw new JSONProcessingError(`JSON parsing failed: ${e.message}`);
        }
    }
}

function parseAndValidate(content, validateModel, repair = true) {
    /**
     * Parst und validiert JSON gegen ein Model.
     * 
     * @param {string} content - JSON-String
     * @param {Function} validateModel - Validierungsmodel (Konstruktor)
     * @param {boolean} repair - Ob Reparatur versucht werden soll
     * @returns {Object} - Validiertes JSON
     */
    const data = parseJson(content, repair);
    // In JS können wir keine echte Pydantic-Validierung machen,
    // aber wir simulieren es durch einen Konstruktoraufruf
    if (validateModel && typeof validateModel === 'function') {
        try {
            return new validateModel(data);
        } catch (validationError) {
            throw new JSONProcessingError(`Validation failed: ${validationError.message}`);
        }
    }
    return data;
}

async function processBatch(inputs, processor, maxWorkers = 4) {
    /**
     * Verarbeitet eine Liste von Inputs parallel.
     *
     * @param {Array} inputs - Liste der zu verarbeitenden Eingaben
     * @param {Function} processor - Funktion, die (input, index) -> BatchResult zurückgibt
     * @param {number} maxWorkers - Anzahl paralleler Worker
     * @returns {Promise<Array>} - Liste der BatchResult-Objekte
     */
    const results = [];
    const workerPromises = [];
    const workers = Math.min(maxWorkers, inputs.length);
    
    // Chunk inputs for workers
    const chunks = Array.from({ length: workers }, (_, i) => 
        inputs.filter((_, idx) => idx % workers === i)
    );
    
    for (let workerIdx = 0; workerIdx < workers; workerIdx++) {
        const chunk = chunks[workerIdx];
        workerPromises.push(
            Promise.all(
                chunk.map(async (inp, localIdx) => {
                    const globalIdx = inputs.indexOf(inp);
                    try {
                        return await processor(inp, globalIdx);
                    } catch (e) {
                        return new BatchResult(
                            globalIdx,
                            String(inp),
                            false,
                            null,
                            `Unexpected error: ${e.message}`
                        );
                    }
                })
            )
        );
    }
    
    const workerResults = await Promise.all(workerPromises);
    for (const workerResult of workerResults) {
        results.push(...workerResult);
    }
    
    // Sortiere nach Index
    results.sort((a, b) => a.index - b.index);
    return results;
}

async function processFileBatch(filePaths, repair = true, validateModel = null, maxWorkers = 4) {
    /**
     * Verarbeitet mehrere JSON-Dateien im Batch.
     *
     * @param {Array<string>} filePaths - Liste der Datei-Pfade
     * @param {boolean} repair - Ob JSON-Reparatur angewendet werden soll
     * @param {Function|null} validateModel - Optionales Validierungsmodell
     * @param {number} maxWorkers - Parallele Worker
     * @returns {Promise<Array>} - Liste der BatchResult-Objekte
     */
    async function processor(filePath, idx) {
        try {
            const content = fs.readFileSync(filePath, 'utf-8');
            
            let data;
            if (validateModel) {
                data = parseAndValidate(content, validateModel, repair);
            } else {
                data = parseJson(content, repair);
            }
            
            return new BatchResult(
                idx,
                filePath,
                true,
                data
            );
        } catch (e) {
            if (e instanceof JSONProcessingError) {
                return new BatchResult(
                    idx,
                    filePath,
                    false,
                    null,
                    e.message
                );
            } else {
                return new BatchResult(
                    idx,
                    filePath,
                    false,
                    null,
                    `${e.constructor.name}: ${e.message}`
                );
            }
        }
    }
    
    return await processBatch(filePaths, processor, maxWorkers);
}

function processJsonlFile(filePath, repair = true, validateModel = null) {
    /**
     * Verarbeitet eine JSON-Lines Datei.
     *
     * @param {string} filePath - Pfad zur .jsonl Datei
     * @param {boolean} repair - Ob Reparatur angewendet werden soll
     * @param {Function|null} validateModel - Optionales Validierungsmodell
     * @returns {Array} - Liste der BatchResult-Objekte
     */
    const results = [];
    const lines = fs.readFileSync(filePath, 'utf-8').split('\n');
    
    for (let lineNum = 0; lineNum < lines.length; lineNum++) {
        const line = lines[lineNum].trim();
        if (!line) continue;
        
        try {
            let data;
            if (validateModel) {
                data = parseAndValidate(line, validateModel, repair);
            } else {
                data = parseJson(line, repair);
            }
            
            results.push(new BatchResult(
                lineNum + 1,
                `${filePath}:${lineNum + 1}`,
                true,
                data
            ));
        } catch (e) {
            if (e instanceof JSONProcessingError) {
                results.push(new BatchResult(
                    lineNum + 1,
                    `${filePath}:${lineNum + 1}`,
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
        if (onlySuccessful && !result.success) {
            continue;
        }
        fs.writeSync(fd, JSON.stringify(result.toDict()) + '\n');
    }
    
    fs.closeSync(fd);
}

async function main() {
    program
        .description('Batch JSON Processor')
        .argument('<inputs...>', 'JSON files to process')
        .option('--jsonl, -l', 'Treat inputs as JSON-Lines files', false)
        .option('--repair, -r', 'Enable JSON repair', true)
        .option('--workers, -w <number>', 'Parallel workers', parseInt, 4)
        .option('--output, -o <file>', 'Output JSON-Lines file')
        .option('--summary, -s', 'Show summary only', false)
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
                allResults = await processFileBatch(
                    inputs,
                    options.repair,
                    null, // validateModel - in JS nicht unterstützt
                    options.workers
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
    
    await program.parseAsync();
}

if (require.main === module) {
    main().catch(err => {
        console.error(err);
        process.exit(1);
    });
}

module.exports = {
    BatchResult,
    JSONProcessingError,
    parseJson,
    parseAndValidate,
    processBatch,
    processFileBatch,
    processJsonlFile,
    writeJsonl,
    readJsonl
};
