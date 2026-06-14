const http = require('http');

const PORT = process.env.PORT || 3000;
const HOST = 'localhost';

console.log('Running integration tests...\n');

const tests = [
    {
        name: 'Root endpoint returns 200',
        path: '/',
        expectStatus: 200,
        validate: (data) => data.message && data.message.includes('Assignment-13')
    },
    {
        name: 'Health endpoint returns healthy status',
        path: '/health',
        expectStatus: 200,
        validate: (data) => data.status === 'healthy'
    }
];

let passed = 0;
let failed = 0;

async function runTest(test) {
    return new Promise((resolve) => {
        const options = {
            hostname: HOST,
            port: PORT,
            path: test.path,
            method: 'GET',
            timeout: 5000
        };

        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                try {
                    const parsed = JSON.parse(data);
                    const statusOk = res.statusCode === test.expectStatus;
                    const validationOk = test.validate(parsed);

                    if (statusOk && validationOk) {
                        console.log(`✅ PASS: ${test.name}`);
                        passed++;
                    } else {
                        console.log(`❌ FAIL: ${test.name}`);
                        console.log(`   Expected status: ${test.expectStatus}, got: ${res.statusCode}`);
                        console.log(`   Response: ${data}`);
                        failed++;
                    }
                } catch (e) {
                    console.log(`❌ FAIL: ${test.name} - Invalid JSON: ${e.message}`);
                    failed++;
                }
                resolve();
            });
        });

        req.on('error', (err) => {
            console.log(`❌ FAIL: ${test.name} - Request error: ${err.message}`);
            failed++;
            resolve();
        });

        req.on('timeout', () => {
            req.destroy();
            console.log(`❌ FAIL: ${test.name} - Request timeout`);
            failed++;
            resolve();
        });

        req.end();
    });
}

async function runAllTests() {
    // Start server in background
    const server = require('./server.js');
    
    // Wait for server to start
    await new Promise(resolve => setTimeout(resolve, 1000));

    for (const test of tests) {
        await runTest(test);
    }

    console.log(`\n${'='.repeat(40)}`);
    console.log(`Tests completed: ${passed} passed, ${failed} failed`);
    console.log(`${'='.repeat(40)}`);

    process.exit(failed > 0 ? 1 : 0);
}

runAllTests();