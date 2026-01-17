const db = require('./db');

async function initDb() {
    try {
        console.log('Initializing database...');

        // Users Table
        await db.query(`
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(50) UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);

        // Messages/Calls Table
        // type: 'sms_inbox', 'sms_sent', 'call_incoming', 'call_outgoing', 'call_missed'
        await db.query(`
            CREATE TABLE IF NOT EXISTS logs (
                id SERIAL PRIMARY KEY,
                user_id INTEGER REFERENCES users(id),
                type VARCHAR(20) NOT NULL,
                remote_number VARCHAR(50),
                remote_name VARCHAR(100),
                content TEXT, -- For SMS
                duration INTEGER, -- For Calls (seconds)
                timestamp BIGINT NOT NULL, -- Unix timestamp from phone
                synced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(user_id, timestamp, remote_number, type) -- Avoid duplicates
            );
        `);

        // Commands Table (for sending SMS from controller)
        await db.query(`
            CREATE TABLE IF NOT EXISTS commands (
                id SERIAL PRIMARY KEY,
                user_id INTEGER REFERENCES users(id),
                type VARCHAR(20) NOT NULL, -- 'send_sms'
                payload JSONB NOT NULL, -- { "to": "+12345", "body": "hello" }
                status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'picked_up', 'completed', 'failed'
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);

        console.log('Database initialized successfully.');
        process.exit(0);
    } catch (err) {
        console.error('Error initializing database:', err);
        process.exit(1);
    }
}

initDb();
