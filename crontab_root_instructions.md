
Um die bereinigte Root-Crontab anzuwenden, führe folgende Schritte aus:

1.  **Kopiere den Inhalt** der Datei `/home/openclaw/.openclaw/workspace/crontab_root_cleaned.txt`.
2.  **Öffne die Root-Crontab zur Bearbeitung:**
    ```bash
    sudo crontab -e
    ```
3.  **Füge den kopierten Inhalt** in den Editor ein. Stelle sicher, dass die Datei sauber ist und keine Duplikate oder Fehler enthält.
4.  **Speichere die Änderungen und beende den Editor.**

Beispiel für die Ausführung auf dem Server:

```bash
# Schritt 1: Kopiere den Inhalt (im Terminal oder über eine Dateiübertragung)
# Beispiel: cat /home/openclaw/.openclaw/workspace/crontab_root_cleaned.txt

# Schritt 2: Bearbeite die Crontab als root
sudo crontab -e

# Schritt 3: Füge den Inhalt ein, speichere und schließe den Editor.
```
