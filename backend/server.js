const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const syncRoutes = require('./routes/sync');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ limit: '50mb', extended: true }));

// Request logging middleware
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);
    next();
});

// Routes
app.use('/auth', authRoutes);
app.use('/sync', syncRoutes);

app.get('/', (req, res) => {
    res.send('SMS Sync Backend is running');
});

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
