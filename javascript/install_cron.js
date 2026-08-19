#!/usr/bin/env node
// install_cron.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/install_cron.py
// auch in: OpenClaw@gateway2:skills/db-maintainer/scripts/install_cron.py
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

/**
 * Installiert den DB-Maintainer als Cron-Job
 */

const fs = require('fs');
const path = require('path');

const CRON_JOB = `
# DB Maintainer - Alle 30 Minuten
*/30 * * * * cd /home/openclaw/.openclaw/workspace && python3 skills/db-maintainer/scripts/db_maintainer.py >> logs/db-maintainer/cron.log 2>&1
`.trim();

function install() {
    const workspace = '/home/openclaw/.openclaw/workspace';
    const cronDir = path.join(workspace, 'crons');
    const cronFile = path.join(cronDir, 'db-maintainer.cron');
    
    // Erstelle das Verzeichnis falls es nicht existiert
    if (!fs.existsSync(cronDir)) {
        fs.mkdirSync(cronDir, { recursive: true });
    }
    
    // Schreibe die Cron-Job Datei
    fs.writeFileSync(cronFile, CRON_JOB);
    
    console.log(`✅ Cron-Job installiert: ${cronFile}`);
    console.log('   Füge zu crontab hinzu mit: crontab < crons/db-maintainer.cron');
    
    // Auch in OpenClaw cron registrieren
    const jobsJson = path.join(workspace, '.openclaw', 'cron', 'jobs.json');
    
    if (fs.existsSync(jobsJson)) {
        const jobsData = fs.readFileSync(jobsJson, 'utf8');
        const jobs = JSON.parse(jobsData);
        
        jobs['db-maintainer'] = {
            schedule: '*/30 * * * *',
            command: 'python3 skills/db-maintainer/scripts/db_maintainer.py',
            enabled: true
        };
        
        fs.writeFileSync(jobsJson, JSON.stringify(jobs, null, 2));
        
        console.log('✅ In OpenClaw cron registriert');
    }
}

install();
