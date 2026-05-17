### Fehlerbehebung bei NPM und Berechtigungen

## Node 1
- **Benutzer:** root  
- **Befehle:**
  ```bash
  npm update
  npm upgrade
  ```  

## Node 2
- **Benutzer:** openclaw  
- **Befehle:**
  ```bash
  sudo npm update
  sudo npm upgrade
  sudo npm cache clean --force
  ```  

## Node 3
- **Benutzer:** root  
- **Befehle:**
  ```bash
  sudo ls -l /root/npm-shrinkwrap.json
  # Ausgabe: ls: cannot access '/root/npm-shrinkwrap.json': No such file or directory
  ```  

## Beispiel für Berechtigungsprobleme

### Beispiel 1 - Berechtigungsfehler
```bash
openclaw@v2202604104722446711:/root$ sudo ls -l /root/npm-shrinkwrap.json
# Ausgabe: ls: cannot access '/root/npm-shrinkwrap.json': No such file or directory
```

### Beispiel 2 - Cache-Bereinigung
```bash
root@v2202604104722446711:~# sudo npm cache clean --force
# Ausgabe: npm warn using --force Recommended protections disabled.
```

## Hinweise
- Der Befehl `sudo npm cache clean --force` kann genutzt werden, um Cache-Probleme zu beheben.