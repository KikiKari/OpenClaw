# Web Search für IT-Operations & Serverwartung

**Zielgruppe:** Systemadministratoren, DevOps, SRE  
**Szenarien:** Incident Response, Monitoring, Dokumentation, Compliance

---

## Use Cases nach IT-Bereich

### 1. Incident Response

```
Alert: CPU-Usage > 95% auf prod-db-03
       └── Was sind typische Ursachen?
           └── EXA/Perplexity: "MySQL high CPU causes"
       └── Gibt es aktuelle CVEs?
           └── Tavily: security advisories + CVE-Check
       └── Wie wurde das bei anderen gelöst?
           └── Firecrawl: StackOverflow/Reddit Threads crawlen
```

**Implementierung:**
```bash
# /opt/ops/incident-helper.sh
INCIDENT_TYPE="$1"

# 1. Schnelle Recherche
EXA_RESULT=$(curl -s -X POST https://api.exa.ai/search \
  -H "Authorization: Bearer $EXA_API_KEY" \
  -d "{\"query\": \"$INCIDENT_TYPE troubleshooting\", \"numResults\": 5}")

# 2. CVE-Check
TAVILY_RESULT=$(tvly search "CVE $INCIDENT_TYPE" --topic news --time-range week)

# 3. Playbook-Update
INCIDENT_DOC="/opt/runbooks/incidents/${INCIDENT_TYPE// /_}.md"
echo "## $(date)" >> "$INCIDENT_DOC"
echo "$EXA_RESULT" | jq -r '.results[0].text' >> "$INCIDENT_DOC"
```

---

### 2. Patch Management

```bash
# /opt/ops/patch-research.sh
SOFTWARE="$1"  # z.B. "nginx", "postgresql"
VERSION="$2"   # z.B. "1.25.3"

echo "🔍 Recherche für $SOFTWARE $VERSION..."

# Security Advisories
ADVISORIES=$(tvly research \
  "$SOFTWARE $VERSION security vulnerabilities patches" \
  --model pro \
  --json | jq -r '.results[] | select(.title | contains("CVE"))')

# Changelog Analysis
curl -s "https://$SOFTWARE.org/CHANGES" > /tmp/changes.txt
CHANGES=$(tvly extract /tmp/changes.txt \
  --query "breaking changes security fixes $VERSION" \
  --chunks-per-source 3)

# Entscheidungsmatrix
if echo "$ADVISORIES" | grep -q "CRITICAL"; then
  echo "🚨 KRITISCH: Sofortiges Patching erforderlich"
  echo "$ADVISORIES" | mail -s "CRITICAL: $SOFTWARE Update" ops-team@example.com
elif echo "$CHANGES" | grep -q "security"; then
  echo "⚠️ Sicherheitsrelevant: Patch innerhalb 7 Tage"
else
  echo "✅ Standard-Update: Nächstes Wartungsfenster"
fi
```

---

### 3. Capacity Planning

```bash
# /opt/ops/capacity-research.sh
TECH_STACK="Kubernetes 1.32 with containerd on AMD EPYC"

tvly research \
  "Capacity planning best practices $TECH_STACK \
   resource allocation limits production" \
  --model pro \
  -o "/opt/docs/capacity_$(date +%Y%m).md"
```

---

### 4. Disaster Recovery

```bash
# /opt/ops/dr-runbook-updater.sh

echo "🔄 Aktualisiere DR-Playbooks..."

# Aktuelle Best Practices
LATEST=$(perplexity/sonar:online \
  "Disaster Recovery best practices 2025 \
   RTO RPO cloud-native kubernetes")

# Lokal speichern
echo "$LATEST" > /opt/runbooks/DR_TEMPLATE.md

# Diff zu bestehendem Playbook
diff /opt/runbooks/DR_CURRENT.md /opt/runbooks/DR_TEMPLATE.md \
  > /opt/runbooks/DR_CHANGES_$(date +%Y%m%d).diff

if [ -s /opt/runbooks/DR_CHANGES_*.diff ]; then
  echo "📋 Änderungen vorgeschlagen - Review erforderlich"
fi
```

---

### 5. Compliance & Audit

```bash
# /opt/ops/compliance-check.sh
REGULATION="$1"  # z.B. "GDPR", "SOC2", "ISO27001"
SYSTEM="$2"      # z.B. "AWS VPC", "Kubernetes"

# Nur lokale/verifizierte Quellen
echo "🔒 Compliance-Check für $REGULATION auf $SYSTEM..."

# Interne Dokumentation (SearXNG)
INTERNAL=$(curl -s "http://localhost:8888/search?q=$REGULATION+$SYSTEM&format=json" \
  | jq -r '.results[].url')

# Externe verifizierte Quellen (Perplexity)
EXTERNAL=$(curl -s -X POST https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_KEY" \
  -d "{
    \"model\": \"perplexity/sonar-pro\",
    \"messages\": [{\"role\": \"user\", \"content\": \"$REGULATION requirements for $SYSTEM - official sources only\"}]
  }" | jq -r '.choices[0].message.annotations[] | .url_citation.url')

# Gap Analysis
REPORT="/opt/compliance/gaps_${REGULATION}_${SYSTEM}_$(date +%Y%m%d).md"
echo "# Gap Analysis: $REGULATION on $SYSTEM" > "$REPORT"
echo "## Interne Dokumentation" >> "$REPORT"
echo "$INTERNAL" >> "$REPORT"
echo "## Externe Anforderungen" >> "$REPORT"
echo "$EXTERNAL" >> "$REPORT"
```

---

## Integration mit Monitoring-Stack

### Alertmanager Webhook
```yaml
# /opt/prometheus/alertmanager-websearch.yml
receivers:
  - name: 'websearch-research'
    webhook_configs:
      - url: 'http://localhost:5000/research-alert'
        send_resolved: false
```

```python
# /opt/prometheus/websearch-webhook.py
from flask import Flask, request
import subprocess
import json

app = Flask(__name__)

@app.route('/research-alert', methods=['POST'])
def research_alert():
    alert = request.json
    summary = alert['groupLabels']['alertname']
    
    # Automatische Recherche
    result = subprocess.run(
        ['tvly', 'search', summary, '--max-results', '3', '--json'],
        capture_output=True, text=True
    )
    
    findings = json.loads(result.stdout)
    
    # An Team senden
    subprocess.run([
        'mail', '-s', f'[AUTO-RESEARCH] {summary}',
        'oncall@example.com'
    ], input=str(findings))
    
    return 'OK'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

---

## Integration mit Ticketing

### Jira Automation
```bash
# /opt/ops/jira-research.sh
TICKET_ID="$1"
DESCRIPTION=$(jira view "$TICKET_ID" --field description)

# Recherche
RESEARCH=$(tvly research "$DESCRIPTION" --model pro)

# Als Kommentar hinzufügen
jira comment "$TICKET_ID" "Auto-Research:\n$RESEARCH"
```

---

## Runbook-Beispiele

### MySQL Performance Issue
```markdown
# Runbook: MySQL High CPU

## 1. Diagnose
```sql
SHOW PROCESSLIST;
SELECT * FROM performance_schema.threads;
```

## 2. Auto-Research
```bash
# Ausführen und Ergebnisse prüfen
/opt/ops/research-alert.sh "MySQL cpu_usage_high"
```

## 3. Häufige Ursachen
- Long-running queries → EXPLAIN ANALYZE
- Missing indexes → pt-query-digest
- Connection pooling → SHOW STATUS LIKE 'Threads_connected'

## 4. Eskalation
Wenn keine Lösung in 30min: Research-Ergebnisse an DBA-Team senden
```

---

## Checkliste: Neue Server-Integration

- [ ] API-Keys in `/etc/environment` hinterlegt
- [ ] Scripts nach `/opt/ops/` kopiert
- [ ] Cron-Jobs aktiviert
- [ ] Monitoring-Webhooks konfiguriert
- [ ] Runbooks mit Auto-Research verknüpft
- [ ] Playbooks in Git versioniert

---

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| API-Limit erreicht | Auf Tavily CLI (lokaler Cache) oder SearXNG (lokal) umstellen |
| Keine Ergebnisse | Query vereinfachen, `search_depth: basic` nutzen |
| Falsche Information | Perplexity (verifizierte Quellen) oder Firecrawl (Originale crawlen) |
| Latenz zu hoch | EXA (ultra-fast mode) oder lokaler SearXNG |

---

**Stand:** 2026-04-18  
**Standort:** `/opt/ops/` oder `~/workspace/OPS/`
