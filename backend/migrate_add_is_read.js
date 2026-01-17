const db = require('./db');

async function migrate() {
    try {
        console.log('Migrating database: Adding is_read column...');

        await db.query(`
            ALTER TABLE logs 
            ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;
        `);

        console.log('Migration successful.');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrate();
