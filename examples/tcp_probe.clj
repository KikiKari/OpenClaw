(ns tcp-probe
  (:import [java.net Socket InetSocketAddress]))

;; OpenClaw TCP port probe (Clojure) — checks gateway nodes
(defn probe [host port timeout-ms]
  (try
    (doto (Socket.)
      (.connect (InetSocketAddress. ^String host (int port)) (int timeout-ms))
      (.close))
    true
    (catch Exception _ false)))

(defn -main [& _]
  (doseq [[host port] [["localhost" 8080] ["localhost" 8081]]]
    (println (str (if (probe host port 3000) "OK  " "FAIL") " " host ":" port))))

(-main)
