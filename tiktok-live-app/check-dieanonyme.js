// LEGACY PROTOTYPE: retained for history only.
// Use tiktok-monitor/tiktok_dispatch.py for normalized status/URL results.
const { WebcastPushConnection } = require('tiktok-live-connector');
const username = process.argv[2] || 'example_creator';
const connection = new WebcastPushConnection(username);

async function getStreamUrl() {
    try {
        const state = await connection.getRoomInfo();
        
        if (state.isLive && state.streamUrl) {
            console.log('FLV_URL:', state.streamUrl.flv_url || 'NOT_FOUND');
            console.log('HLS_URL:', state.streamUrl.hls_url || 'NOT_FOUND');
        } else {
            console.log('OFFLINE');
        }
    } catch (e) {
        console.log('ERROR:', e.message);
    }
    process.exit(0);
}

getStreamUrl();
