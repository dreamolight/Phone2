const db = require('./db');

async function debugData() {
    try {
        console.log('--- Debugging Data ---');

        // 1. List Users
        const users = await db.query('SELECT id, username FROM users');
        console.log('Users:', users.rows);

        if (users.rows.length === 0) {
            console.log('No users found!');
            return;
        }

        // 2. Check Logs for the first user (usually testuser)
        const userId = users.rows.find(u => u.username === 'testuser')?.id;

        if (!userId) {
            console.log('testuser not found.');
            return;
        }

        console.log(`Checking logs for testuser (ID: ${userId})...`);
        const logs = await db.query('SELECT * FROM logs WHERE user_id = $1', [userId]);
        console.log(`Total Logs found: ${logs.rows.length}`);
        if (logs.rows.length > 0) {
            console.log('Sample Log:', logs.rows[0]);
        }

        // 3. Test the Conversation Query
        console.log('Testing Conversation Query...');
        const query = `
            SELECT DISTINCT ON (remote_number)
                remote_number,
                remote_name,
                content,
                type,
                timestamp,
                duration
            FROM logs
            WHERE user_id = $1
            ORDER BY remote_number, timestamp DESC
        `;
        const convs = await db.query(query, [userId]);
        console.log('Conversations Found:', convs.rows);

        process.exit(0);

    } catch (err) {
        console.error('Debug Error:', err);
        process.exit(1);
    }
}

debugData();
