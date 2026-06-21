// @deprecated Legacy API probe. Not a canonical Live-status signal.
// See /home/openclaw/.openclaw/workspace/TIKTOK-CURRENT.md.
const { WebcastPushConnection } = require('tiktok-live-connector');

const username = process.argv[2]?.replace(/^@+/, '') || 'example_creator';
const connection = new WebcastPushConnection(username);

async function checkLiveStatus() {
    try {
        const state = await connection.getRoomInfo();
        
        if (state.isLive) {
            console.log(`✅ @${username} IST LIVE!`);
            console.log(`Stream ID: ${state.roomId}`);
            console.log(`Zuschauer: ${state.viewerCount || 'unbekannt'}`);
            console.log(`Startzeit: ${new Date().toLocaleString('de-DE')}`);
        } else {
            console.log(`❌ @${username} ist NICHT live.`);
        }
        
        process.exit(0);
    } catch (error) {
        console.error(`Fehler beim Prüfen des Status: ${error.message}`);
        process.exit(1);
    }
}

checkLiveStatus();
