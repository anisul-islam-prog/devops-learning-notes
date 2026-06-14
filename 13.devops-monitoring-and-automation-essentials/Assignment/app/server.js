const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        hostname: os.hostname()
    });
});

// Main endpoint
app.get('/', (req, res) => {
    res.status(200).json({
        message: 'Hello from Assignment-13 App!',
        version: '1.0.0',
        environment: process.env.NODE_ENV || 'development',
        timestamp: new Date().toISOString()
    });
});

// Simulate CPU load endpoint (for Zabbix testing)
app.get('/load', (req, res) => {
    const start = Date.now();
    while (Date.now() - start < 5000) {
        Math.random() * Math.random();
    }
    res.status(200).json({
        message: 'CPU load generated for 5 seconds',
        timestamp: new Date().toISOString()
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
});