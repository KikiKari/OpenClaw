(ns gateway-client)

;; OpenClaw Gateway Client (Clojure) — via java.net.http interop
(defn check-health [base-url]
  (let [client  (java.net.http.HttpClient/newHttpClient)
        request (-> (java.net.http.HttpRequest/newBuilder)
                    (.uri (java.net.URI/create (str base-url "/health")))
                    (.timeout (java.time.Duration/ofSeconds 5))
                    (.GET)
                    (.build))
        handler (java.net.http.HttpResponse$BodyHandlers/ofString)
        response (.send client request handler)]
    (.statusCode response)))

(defn -main [& args]
  (let [url (or (first args) "http://localhost:8080")]
    (println (str "Gateway " url " -> HTTP " (check-health url)))))

(apply -main *command-line-args*)
