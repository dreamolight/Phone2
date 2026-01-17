const db = require('./db');

async function clearData() {
    try {
        const userRes = await db.query("SELECT id FROM users WHERE username = 'testuser'");
        if (userRes.rows.length === 0) {
            console.log("User 'testuser' not found.");
            process.exit(1);
        }

        const userId = userRes.rows[0].id;
        console.log(`Found 'testuser' with ID: ${userId}`);

        const res = await db.query("DELETE FROM logs WHERE user_id = $1", [userId]);
        console.log(`Deleted ${res.rowCount} rows from logs for user ${userId}.`);

    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}

clearData();
