// abstraction-provenance: {"artifact_sha256": "8f04a8b6bbe0707814d09846990e3cbfdaf3be64d4958c5870e824cea1a6b5e6", "source_sha256": "8ec3d801d0245c44e6cd926baa89388c6e541d4fa4c4caa70ff0c0c94f6369d9", "target_language": "go"}
// sqlite-vec-smoke.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sqlite-vec-smoke.mjs
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	"github.com/glebarez/go-sqlite"
	_ "github.com/glebarez/go-sqlite"
)

func vec(values []float32) []byte {
	buf := make([]byte, len(values)*4)
	for i, v := range values {
		u := *(*uint32)(unsafe.Pointer(&v))
		buf[i*4+0] = byte(u)
		buf[i*4+1] = byte(u >> 8)
		buf[i*4+2] = byte(u >> 16)
		buf[i*4+3] = byte(u >> 24)
	}
	return buf
}

func main() {
	db, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		log.Fatal("Failed to open database:", err)
	}
	defer db.Close()

	// Enable extensions
	_, err = db.Exec("PRAGMA foreign_keys = ON")
	if err != nil {
		log.Fatal("Failed to enable foreign keys:", err)
	}

	// Note: In Go we cannot dynamically load SQLite extensions like in Node.js
	// The sqlite-vec functionality would need to be compiled into the binary
	// or available as a Go package. For this example, we'll assume the vec0
	// module is available through the SQLite build.

	_, err = db.Exec(`
		CREATE VIRTUAL TABLE v USING vec0(
			id TEXT PRIMARY KEY,
			embedding FLOAT[4]
		);
	`)
	if err != nil {
		log.Fatal("Failed to create virtual table:", err)
	}

	insertStmt, err := db.Prepare("INSERT INTO v (id, embedding) VALUES (?, ?)")
	if err != nil {
		log.Fatal("Failed to prepare insert statement:", err)
	}
	defer insertStmt.Close()

	_, err = insertStmt.Exec("a", vec([]float32{1, 0, 0, 0}))
	if err != nil {
		log.Fatal("Failed to insert 'a':", err)
	}

	_, err = insertStmt.Exec("b", vec([]float32{0, 1, 0, 0}))
	if err != nil {
		log.Fatal("Failed to insert 'b':", err)
	}

	_, err = insertStmt.Exec("c", vec([]float32{0.2, 0.2, 0, 0}))
	if err != nil {
		log.Fatal("Failed to insert 'c':", err)
	}

	queryVec := vec([]float32{1, 0, 0, 0})
	rows, err := db.Query("SELECT id, vec_distance_cosine(embedding, ?) AS dist FROM v ORDER BY dist ASC", queryVec)
	if err != nil {
		log.Fatal("Query failed:", err)
	}
	defer rows.Close()

	fmt.Println("sqlite-vec ok")

	var results []map[string]interface{}
	for rows.Next() {
		var id string
		var dist float64
		err := rows.Scan(&id, &dist)
		if err != nil {
			log.Fatal("Failed to scan row:", err)
		}
		results = append(results, map[string]interface{}{
			"id":   id,
			"dist": dist,
		})
	}

	if err = rows.Err(); err != nil {
		log.Fatal("Row iteration error:", err)
	}

	fmt.Println(results)
}
