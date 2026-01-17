const db = require('./routes/db');

async function check() {
    try {
        const userId = 1; // Assuming user ID 1 for test (or check all)
        console.log('Checking unread counts for all users...');
        const res = await db.query(`
            SELECT user_id, 
                   SUM(CASE WHEN type='sms_inbox' THEN 1 ELSE 0 END) as msg_count,
                   SUM(CASE WHEN type IN ('call_missed', 'call_incoming') THEN 1 ELSE 0 END) as call_count
            FROM logs 
            WHERE is_read = FALSE
            GROUP BY user_id
        `);
        console.log('Unread Counts per User:', res.rows);
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
check();
