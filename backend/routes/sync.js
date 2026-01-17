const express = require('express');
const router = express.Router();
const db = require('../db');
const authenticateToken = require('../middleware/authMiddleware');

router.use(authenticateToken);

// Upload logs (SMS/Call history)
router.post('/upload', async (req, res) => {
    const { logs } = req.body; // Array of objects
    if (!logs || !Array.isArray(logs)) {
        return res.status(400).send('Invalid data format');
    }

    const userId = req.user.id;

    try {
        // We use a transaction or just loop insert. Batch insert is better but loop is easier for now.
        // Using ON CONFLICT DO NOTHING to avoid duplicates if re-uploaded
        // Note: logs table constraint: UNIQUE(user_id, timestamp, remote_number, type)

        // Construct bulk insert query could be complex with PG, so start with simple loop
        // Helper to remove null bytes and other control characters which Postgres might hate
        const clean = (str) => {
            if (typeof str !== 'string') return str;
            // Remove null bytes and other non-printable chars (keep \n \r \t)
            // eslint-disable-next-line no-control-regex
            return str.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, '');
        };

        for (const log of logs) {
            await db.query(`
                INSERT INTO logs (user_id, type, remote_number, remote_name, content, duration, timestamp, is_read)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                ON CONFLICT (user_id, timestamp, remote_number, type) 
                DO UPDATE SET 
                    remote_name = EXCLUDED.remote_name,
                    content = EXCLUDED.content,
                    synced_at = CURRENT_TIMESTAMP,
                    is_read = CASE 
                        WHEN logs.is_read = TRUE THEN TRUE 
                        ELSE EXCLUDED.is_read 
                    END
            `, [
                userId,
                clean(log.type),
                clean(log.remote_number),
                clean(log.remote_name),
                clean(log.content),
                log.duration,
                log.timestamp,
                log.is_read // New field from mobile
            ]);
        }
        res.sendStatus(200);
    } catch (err) {
        console.error("UPLOAD ERROR:", err);
        res.status(500).send(`Server Error: ${err.message}`);
    }
});

// Get Conversations (Unique list with last message)
router.get('/conversations', async (req, res) => {
    const userId = req.user.id;
    const { category } = req.query; // 'messages' or 'calls'

    try {
        let typeFilter = '';
        if (category === 'messages') {
            typeFilter = "AND type IN ('sms_inbox', 'sms_sent')";
        } else if (category === 'calls') {
            typeFilter = "AND type IN ('call_incoming', 'call_outgoing', 'call_missed')";
        }

        // Complex query to get last message for each unique remote_number
        // We group by remote_number and get the max timestamp, then join back to get content.
        // OR using DISTINCT ON in Postgres
        const query = `

            SELECT DISTINCT ON(l1.remote_number)
        l1.remote_number,
            l1.remote_name,
            l1.content,
            l1.type,
            l1.timestamp,
            l1.duration,
            (SELECT COUNT(*) FROM logs l2 
                 WHERE l2.user_id = $1 
                 AND l2.remote_number = l1.remote_number 
                 AND l2.is_read = FALSE
                 AND l2.type IN('sms_inbox', 'call_missed', 'call_incoming')
                ) as unread_count
            FROM logs l1
            WHERE l1.user_id = $1 ${typeFilter}
            ORDER BY l1.remote_number, l1.timestamp DESC
    `;

        const result = await db.query(query, [userId]);

        // Debug
        // console.log("Conversations fetched:", result.rows.length);
        // if (result.rows.length > 0) console.log("First row unread:", result.rows[0].unread_count, "Type:", typeof result.rows[0].unread_count);

        // Improve sort: client wants most recent conversation first, but DISTINCT ON sorted by remote_number first.
        const sortedResult = result.rows.sort((a, b) => b.timestamp - a.timestamp);

        res.json(sortedResult);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// Get Messages for a specific conversation
router.get('/messages', async (req, res) => {
    const userId = req.user.id;
    const { remote_number, limit = 50, offset = 0 } = req.query;

    if (!remote_number) return res.status(400).send('remote_number required');

    try {
        const result = await db.query(`
SELECT * FROM logs 
            WHERE user_id = $1 AND remote_number = $2
            ORDER BY timestamp DESC 
            LIMIT $3 OFFSET $4
    `, [userId, remote_number, limit, offset]);
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// Mark all messages as read for a conversation
router.post('/mark_read', async (req, res) => {
    const userId = req.user.id;
    const { remote_number } = req.body;

    if (!remote_number) return res.status(400).send('remote_number required');

    try {
        await db.query(`
            UPDATE logs 
            SET is_read = TRUE 
            WHERE user_id = $1 AND remote_number = $2
    `, [userId, remote_number]);
        res.sendStatus(200);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// Get global unread counts
router.get('/unread_counts', async (req, res) => {
    const userId = req.user.id;
    try {
        const result = await db.query(`
            SELECT 
                SUM(CASE WHEN type = 'sms_inbox' THEN 1 ELSE 0 END) as messages,
                SUM(CASE WHEN type IN ('call_missed', 'call_incoming') THEN 1 ELSE 0 END) as calls
            FROM logs 
            WHERE user_id = $1 AND is_read = FALSE
        `, [userId]);

        const counts = result.rows[0] || { messages: 0, calls: 0 };
        console.log('DEBUG: unread_counts:', counts);
        res.json({
            messages: parseInt(counts.messages || 0),
            calls: parseInt(counts.calls || 0)
        });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// Mark all logs in a category as read
router.post('/mark_category_read', async (req, res) => {
    const userId = req.user.id;
    const { category } = req.body; // 'messages' or 'calls'

    let typeFilter = '';
    if (category === 'messages') {
        typeFilter = "AND type = 'sms_inbox'";
    } else if (category === 'calls') {
        typeFilter = "AND type IN ('call_missed', 'call_incoming')";
    } else if (category === 'all') {
        typeFilter = ""; // No filter, update all
    } else {
        return res.status(400).send('Invalid category');
    }

    try {
        await db.query(`
            UPDATE logs 
            SET is_read = TRUE 
            WHERE user_id = $1 AND is_read = FALSE ${typeFilter}
        `, [userId]);
        res.sendStatus(200);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// Fetch logs (Legacy/All)
router.get('/fetch', async (req, res) => {
    const userId = req.user.id;
    const limit = parseInt(req.query.limit) || 100;
    const offset = parseInt(req.query.offset) || 0;

    try {
        const result = await db.query(`
SELECT * FROM logs 
            WHERE user_id = $1 
            ORDER BY timestamp DESC 
            LIMIT $2 OFFSET $3
    `, [userId, limit, offset]);
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// Send Command (Controller -> Server)
router.post('/command', async (req, res) => {
    const userId = req.user.id;
    const { type, payload } = req.body;

    if (!type || !payload) return res.status(400).send('Missing fields');

    try {
        await db.query(`
            INSERT INTO commands(user_id, type, payload)
VALUES($1, $2, $3)
    `, [userId, type, payload]);
        res.sendStatus(200);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// Get Commands (Uploader -> Server)
router.get('/commands', async (req, res) => {
    const userId = req.user.id;

    try {
        // Fetch pending commands
        const result = await db.query(`
SELECT * FROM commands
            WHERE user_id = $1 AND status = 'pending'
            ORDER BY created_at ASC
    `, [userId]);

        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// Update command status (Uploader -> Server)
router.post('/command/:id/status', async (req, res) => {
    const userId = req.user.id;
    const commandId = req.params.id;
    const { status } = req.body;

    try {
        await db.query(`
            UPDATE commands SET status = $1, updated_at = CURRENT_TIMESTAMP
            WHERE id = $2 AND user_id = $3
    `, [status, commandId, userId]);
        res.sendStatus(200);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// Get Upload Status (Max timestamps)
router.get('/status', async (req, res) => {
    const userId = req.user.id;
    try {
        // sms max
        const smsRes = await db.query(`
            SELECT MAX(timestamp) as max_ts FROM logs 
            WHERE user_id = $1 AND type IN ('sms_inbox', 'sms_sent')
`, [userId]);

        // call max
        const callRes = await db.query(`
            SELECT MAX(timestamp) as max_ts FROM logs 
            WHERE user_id = $1 AND type IN ('call_incoming', 'call_outgoing', 'call_missed')
`, [userId]);

        res.json({
            lastSmsTimestamp: smsRes.rows[0].max_ts ? parseInt(smsRes.rows[0].max_ts) : 0,
            lastCallTimestamp: callRes.rows[0].max_ts ? parseInt(callRes.rows[0].max_ts) : 0,
        });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

module.exports = router;
