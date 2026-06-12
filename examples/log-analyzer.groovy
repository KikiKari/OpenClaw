// OpenClaw log analyzer (Groovy) — parses gateway access logs from stdin
def pattern = ~/^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$/
def counts = [INFO: 0, WARN: 0, ERROR: 0]

System.in.eachLine { line ->
    def m = pattern.matcher(line)
    if (m.matches()) {
        def level = m.group(2)
        counts[level]++
        if (level == 'ERROR') println "⚠ ${m.group(1)} [${m.group(3)}] ${m.group(4)}"
    }
}

println "\n--- Summary ---"
['ERROR', 'INFO', 'WARN'].each { level -> println "${level}: ${counts[level]}" }
