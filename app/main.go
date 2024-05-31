package main

import (
	"fmt"
	"net/http"
	"os"
)

func main() {
	ip := os.Getenv("POD_IP")
	version := os.Getenv("VERSION")
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) { fmt.Fprintf(w, "[%v] -> [%v]\n", version, ip) })
	http.ListenAndServe(":8080", nil)
}
