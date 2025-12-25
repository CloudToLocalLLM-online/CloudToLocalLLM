/** @type {import('@playwright/test').PlaywrightTestConfig} */
const config = {
    testDir: './test/e2e',
    timeout: 30 * 1000,
    expect: {
        timeout: 5000
    },
    fullyParallel: true,
    forbidOnly: !!process.env.CI,
    retries: process.env.CI ? 2 : 0,
    workers: process.env.CI ? 1 : undefined,
    reporter: 'html',
    globalSetup: './test/e2e/global-setup',
    globalTeardown: './test/e2e/global-teardown',
    use: {
        actionTimeout: 0,
        trace: 'on-first-retry',
    },
    projects: [
        {
            name: 'chromium',
            use: {
                browserName: 'chromium',
            },
        },
    ],
};

export default config;
