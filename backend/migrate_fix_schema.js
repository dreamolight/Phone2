const db = require('./db');

async function migrate() {
    try {
        console.log('Migrating schema...');

        // Alter output of remote_number to TEXT to avoid truncation
        await db.query("ALTER TABLE logs ALTER COLUMN remote_number TYPE TEXT");
        await db.query("ALTER TABLE logs ALTER COLUMN type TYPE TEXT");

        console.log('Schema migration successful.');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrate();
