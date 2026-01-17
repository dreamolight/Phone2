const db = require('./db');
const bcrypt = require('bcryptjs');

async function seedData() {
    try {
        console.log('Seeding data...');

        const username = 'testuser';
        const password = 'password123';
        const hashedPassword = await bcrypt.hash(password, 10);

        // 1. Create User
        // Check if exists first to avoid error or duplicate logic
        const userCheck = await db.query('SELECT id FROM users WHERE username = $1', [username]);
        let userId;

        if (userCheck.rows.length > 0) {
            userId = userCheck.rows[0].id;
            console.log(`User '${username}' already exists (ID: ${userId})`);
        } else {
            const userResult = await db.query(
                'INSERT INTO users (username, password_hash) VALUES ($1, $2) RETURNING id',
                [username, hashedPassword]
            );
            userId = userResult.rows[0].id;
            console.log(`Created user '${username}' (ID: ${userId})`);
        }

        // 2. Insert Dummy Logs
        const now = Date.now();
        const logs = [
            {
                type: 'sms_inbox',
                remote_number: '+15550123',
                remote_name: 'Mom',
                content: 'Hey, are you coming over for dinner?',
                timestamp: now - 1000 * 60 * 60 * 2, // 2 hours ago
            },
            {
                type: 'sms_sent',
                remote_number: '+15550123',
                remote_name: 'Mom',
                content: 'Yes, be there at 6!',
                timestamp: now - 1000 * 60 * 60 * 1.9,
            },
            {
                type: 'call_missed',
                remote_number: '+15559999',
                remote_name: 'Unknown',
                timestamp: now - 1000 * 60 * 60 * 24, // 1 day ago
                duration: 0
            },
            {
                type: 'sms_inbox',
                remote_number: '12345',
                remote_name: 'Bank Alert',
                content: 'Your verification code is 8842.',
                timestamp: now - 1000 * 60 * 5, // 5 mins ago
            },
        ];

        for (const log of logs) {
            await db.query(`
                INSERT INTO logs (user_id, type, remote_number, remote_name, content, duration, timestamp)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                ON CONFLICT (user_id, timestamp, remote_number, type) DO NOTHING
            `, [userId, log.type, log.remote_number, log.remote_name, log.content, 0, log.timestamp]);
        }

        console.log(`Inserted ${logs.length} dummy logs.`);
        process.exit(0);

    } catch (err) {
        console.error('Error seeding data:', err);
        process.exit(1);
    }
}

seedData();
