(ns log-analyzer)

;; OpenClaw log analyzer (Clojure) — parses gateway access logs from stdin
(def pattern #"^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$")

(defn -main [& _]
  (let [counts (atom {"INFO" 0 "WARN" 0 "ERROR" 0})]
    (doseq [line (line-seq (java.io.BufferedReader. *in*))]
      (when-let [[_ ts level node msg] (re-matches pattern line)]
        (swap! counts update level inc)
        (when (= level "ERROR")
          (println (str "⚠ " ts " [" node "] " msg)))))
    (println "\n--- Summary ---")
    (doseq [level ["ERROR" "INFO" "WARN"]]
      (println (str level ": " (@counts level))))))

(-main)
