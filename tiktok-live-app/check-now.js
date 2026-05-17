const { WebcastPushConnection } = require('tiktok-live-connector');
const username = 'yousefbln4444';
const connection = new WebcastPushConnection(username);

async function getStreamUrl() {
    try {
        const state = await connection.getRoomInfo();
        
        if (state.isLive && state.streamUrl) {
            console.log('FLV_URL:', state.streamUrl.flv_url || 'NOT_FOUND');
            console.log('HLS_URL:', state.streamUrl.hls_url || 'NOT_FOUND');
            console.log('RTMP_URL:', state.streamUrl.rtmp_url || 'NOT_FOUND');
        } else {
            console.log('OFFLINE');
        }
    } catch (e) {
        console.log('ERROR:', e.message);
    }
    process.exit(0);
}

getStreamUrl();