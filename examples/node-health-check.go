package main

import (
	"fmt"
	"net/http"
	"os"
	"sync"
	"time"
)

func checkNode(wg *sync.WaitGroup, node string, results chan<- string) {
	defer wg.Done()
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(node + "/health")
	if err != nil {
		results <- fmt.Sprintf("FAIL %s: %v", node, err)
		return
	}
	defer resp.Body.Close()
	results <- fmt.Sprintf("OK   %s: %d", node, resp.StatusCode)
}

func main() {
	nodes := os.Args[1:]
	if len(nodes) == 0 {
		nodes = []string{"http://localhost:8080", "http://localhost:8081"}
	}
	var wg sync.WaitGroup
	results := make(chan string, len(nodes))
	for _, node := range nodes {
		wg.Add(1)
		go checkNode(&wg, node, results)
	}
	wg.Wait()
	close(results)
	for r := range results {
		fmt.Println(r)
	}
}