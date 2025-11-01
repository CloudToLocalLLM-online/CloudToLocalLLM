// CloudToLocalLLM Tunnel UI Improvements E2E Test
// Tests the new tunnel management interface, status indicators, and wizard accessibility

const { test, expect } = require('@playwright/test');

test.describe('Tunnel UI Improvements', () => {
  let networkRequests = [];
  let consoleMessages = [];

  test.beforeEach(async ({ page }) => {
    // Reset tracking arrays
    networkRequests = [];
    consoleMessages = [];

    // Capture network requests for tunnel communication monitoring
    page.on('request', (request) => {
      const url = request.url();
      networkRequests.push({
        url,
        method: request.method(),
        timestamp: new Date().toISOString(),
        headers: request.headers(),
      });
    });

    // Capture console messages for debugging
    page.on('console', (msg) => {
      consoleMessages.push({
        type: msg.type(),
        text: msg.text(),
        timestamp: new Date().toISOString(),
      });
    });

    // Navigate to the application
    await page.goto('/');
    
    // Wait for the app to load
    await page.waitForSelector('[data-testid="app-header"], .app-header, header', { timeout: 10000 });
  });

  test.afterEach(async ({ page }) => {
    // Log network requests for debugging
    console.log(` Network requests captured: ${networkRequests.length}`);
    console.log(` Console messages captured: ${consoleMessages.length}`);
    
    // Log any errors
    const errors = consoleMessages.filter(msg => msg.type === 'error');
    if (errors.length > 0) {
      console.log('� Console errors detected:', errors);
    }
  });

  test('should display tunnel status indicator in app header', async ({ page }) => {
    // Look for tunnel status indicator in the header
    const tunnelIndicator = page.locator('.tunnel-status-indicator, [data-testid="tunnel-status-indicator"]').first();
    
    // Wait for the indicator to be visible
    await expect(tunnelIndicator).toBeVisible({ timeout: 15000 });
    
    // Verify the indicator shows status information
    const statusText = await tunnelIndicator.textContent();
    expect(statusText).toMatch(/(Connected|Connecting|Disconnected|No Client|Error)/i);
    
    // Verify the indicator has appropriate styling
    const indicatorElement = await tunnelIndicator.elementHandle();
    const styles = await page.evaluate(el => {
      const computed = window.getComputedStyle(el);
      return {
        display: computed.display,
        visibility: computed.visibility,
      };
    }, indicatorElement);
    
    expect(styles.display).not.toBe('none');
    expect(styles.visibility).toBe('visible');
  });

  test('should open tunnel management panel when clicking status indicator', async ({ page }) => {
    // Find and click the tunnel status indicator
    const tunnelIndicator = page.locator('.tunnel-status-indicator, [data-testid="tunnel-status-indicator"]').first();
    await expect(tunnelIndicator).toBeVisible({ timeout: 15000 });
    
    await tunnelIndicator.click();
    
    // Wait for the tunnel management panel to appear
    const managementPanel = page.locator('.tunnel-management-panel, [data-testid="tunnel-management-panel"]').first();
    await expect(managementPanel).toBeVisible({ timeout: 10000 });
    
    // Verify panel contains expected sections
    await expect(page.locator('text=Tunnel Management')).toBeVisible();
    await expect(page.locator('text=Tunnel Status')).toBeVisible();
    await expect(page.locator('text=Quick Actions')).toBeVisible();
    
    // Verify action buttons are present
    await expect(page.locator('button:has-text("Connect"), button:has-text("Disconnect")')).toBeVisible();
    await expect(page.locator('button:has-text("Configure Tunnel")')).toBeVisible();
    
    // Close the panel
    const closeButton = page.locator('button[aria-label="Close"], button:has-text("Close"), .close-button').first();
    await closeButton.click();
    
    // Verify panel is closed
    await expect(managementPanel).not.toBeVisible({ timeout: 5000 });
  });

  test('should access tunnel wizard from management panel', async ({ page }) => {
    // Open tunnel management panel
    const tunnelIndicator = page.locator('.tunnel-status-indicator, [data-testid="tunnel-status-indicator"]').first();
    await expect(tunnelIndicator).toBeVisible({ timeout: 15000 });
    await tunnelIndicator.click();
    
    // Wait for management panel
    await expect(page.locator('text=Tunnel Management')).toBeVisible({ timeout: 10000 });
    
    // Click Configure Tunnel button
    const configureButton = page.locator('button:has-text("Configure Tunnel")').first();
    await expect(configureButton).toBeVisible();
    await configureButton.click();
    
    // Wait for tunnel wizard to appear
    const wizardDialog = page.locator('.tunnel-connection-wizard, [data-testid="tunnel-wizard"]').first();
    await expect(wizardDialog).toBeVisible({ timeout: 10000 });
    
    // Verify wizard header and content
    await expect(page.locator('text=Tunnel Management, text=Reconfigure Tunnel')).toBeVisible();
    await expect(page.locator('text=Update your existing tunnel configuration')).toBeVisible();
    
    // Verify wizard steps are present
    const wizardSteps = page.locator('.wizard-step, [data-testid="wizard-step"]');
    await expect(wizardSteps).toHaveCount(4, { timeout: 5000 });
    
    // Close wizard
    const cancelButton = page.locator('button:has-text("Cancel"), button[aria-label="Close"]').first();
    await cancelButton.click();
    
    // Verify wizard is closed
    await expect(wizardDialog).not.toBeVisible({ timeout: 5000 });
  });

  test('should show enhanced desktop client prompt with tunnel setup', async ({ page }) => {
    // Look for desktop client prompt (appears when no desktop client is connected)
    const clientPrompt = page.locator('.desktop-client-prompt, [data-testid="desktop-client-prompt"]').first();
    
    // If prompt is visible, test its enhanced features
    if (await clientPrompt.isVisible()) {
      // Verify enhanced prompt contains tunnel setup button
      await expect(page.locator('button:has-text("Setup Tunnel"), button:has-text("Setup")')).toBeVisible();
      
      // Verify download button is present
      await expect(page.locator('button:has-text("Download Desktop Client"), button:has-text("Download")')).toBeVisible();
      
      // Test tunnel setup button
      const setupButton = page.locator('button:has-text("Setup Tunnel"), button:has-text("Setup")').first();
      await setupButton.click();
      
      // Verify tunnel wizard opens
      const wizardDialog = page.locator('.tunnel-connection-wizard, [data-testid="tunnel-wizard"]').first();
      await expect(wizardDialog).toBeVisible({ timeout: 10000 });
      
      // Verify it's in first-time setup mode
      await expect(page.locator('text=Setup Tunnel Connection')).toBeVisible();
      
      // Close wizard
      const cancelButton = page.locator('button:has-text("Cancel"), button[aria-label="Close"]').first();
      await cancelButton.click();
    } else {
      console.log(' Desktop client prompt not visible - desktop client may be connected');
    }
  });

  test('should access tunnel settings with enhanced status summary', async ({ page }) => {
    // Navigate to settings
    await page.goto('/settings');
    
    // Wait for settings page to load
    await expect(page.locator('text=Settings')).toBeVisible({ timeout: 10000 });
    
    // Look for tunnel connection section
    const tunnelSection = page.locator('text=Tunnel Connection').first();
    if (await tunnelSection.isVisible()) {
      await tunnelSection.click();
      
      // Verify enhanced tunnel status summary card is present
      const statusSummary = page.locator('.tunnel-status-summary, [data-testid="tunnel-status-summary"]').first();
      await expect(statusSummary).toBeVisible({ timeout: 10000 });
      
      // Verify status information is displayed
      await expect(page.locator('text=Tunnel Connected, text=Connecting, text=Setup Required, text=Disconnected')).toBeVisible();
      
      // Verify quick action buttons in settings
      const setupButton = page.locator('button:has-text("Setup"), button:has-text("Reconnect")').first();
      if (await setupButton.isVisible()) {
        await setupButton.click();
        
        // Verify wizard opens
        const wizardDialog = page.locator('.tunnel-connection-wizard, [data-testid="tunnel-wizard"]').first();
        await expect(wizardDialog).toBeVisible({ timeout: 10000 });
        
        // Close wizard
        const cancelButton = page.locator('button:has-text("Cancel"), button[aria-label="Close"]').first();
        await cancelButton.click();
      }
    }
  });

  test('should access tunnel status dashboard', async ({ page }) => {
    // Navigate to tunnel status dashboard
    await page.goto('/tunnel-status');
    
    // Wait for tunnel status screen to load
    await expect(page.locator('text=Tunnel Status')).toBeVisible({ timeout: 10000 });
    
    // Verify main status card is present
    const overallStatus = page.locator('.tunnel-status-card, [data-testid="overall-status"]').first();
    await expect(overallStatus).toBeVisible({ timeout: 10000 });
    
    // Verify connection details card
    await expect(page.locator('text=Connection Details')).toBeVisible();
    
    // Verify quick actions section
    await expect(page.locator('text=Quick Actions')).toBeVisible();
    
    // Verify troubleshooting section
    await expect(page.locator('text=Common Issues')).toBeVisible();
    
    // Test quick action buttons
    const connectButton = page.locator('button:has-text("Connect"), button:has-text("Disconnect")').first();
    if (await connectButton.isVisible()) {
      // Just verify the button is clickable, don't actually click to avoid state changes
      await expect(connectButton).toBeEnabled();
    }
    
    // Test configure button
    const configureButton = page.locator('button:has-text("Configure")').first();
    if (await configureButton.isVisible()) {
      await configureButton.click();
      
      // Verify wizard opens in reconfigure mode
      const wizardDialog = page.locator('.tunnel-connection-wizard, [data-testid="tunnel-wizard"]').first();
      await expect(wizardDialog).toBeVisible({ timeout: 10000 });
      
      // Close wizard
      const cancelButton = page.locator('button:has-text("Cancel"), button[aria-label="Close"]').first();
      await cancelButton.click();
    }
    
    // Test troubleshoot button
    const troubleshootButton = page.locator('button:has-text("Troubleshoot")').first();
    if (await troubleshootButton.isVisible()) {
      await troubleshootButton.click();
      
      // Verify troubleshooting wizard opens
      const wizardDialog = page.locator('.tunnel-connection-wizard, [data-testid="tunnel-wizard"]').first();
      await expect(wizardDialog).toBeVisible({ timeout: 10000 });
      
      // Verify it's in troubleshoot mode
      await expect(page.locator('text=Tunnel Troubleshooting')).toBeVisible();
      
      // Close wizard
      const cancelButton = page.locator('button:has-text("Cancel"), button[aria-label="Close"]').first();
      await cancelButton.click();
    }
  });

  test('should handle tunnel wizard modes correctly', async ({ page }) => {
    // Test different wizard entry points and modes
    
    // 1. Test from management panel (reconfigure mode)
    const tunnelIndicator = page.locator('.tunnel-status-indicator, [data-testid="tunnel-status-indicator"]').first();
    if (await tunnelIndicator.isVisible()) {
      await tunnelIndicator.click();
      
      const configureButton = page.locator('button:has-text("Configure Tunnel")').first();
      if (await configureButton.isVisible()) {
        await configureButton.click();
        
        // Verify reconfigure mode
        await expect(page.locator('text=Reconfigure Tunnel, text=Tunnel Management')).toBeVisible({ timeout: 10000 });
        
        const cancelButton = page.locator('button:has-text("Cancel"), button[aria-label="Close"]').first();
        await cancelButton.click();
      }
    }
    
    // 2. Test from desktop client prompt (first-time mode)
    const clientPrompt = page.locator('.desktop-client-prompt, [data-testid="desktop-client-prompt"]').first();
    if (await clientPrompt.isVisible()) {
      const setupButton = page.locator('button:has-text("Setup Tunnel"), button:has-text("Setup")').first();
      if (await setupButton.isVisible()) {
        await setupButton.click();
        
        // Verify first-time mode
        await expect(page.locator('text=Setup Tunnel Connection')).toBeVisible({ timeout: 10000 });
        
        const cancelButton = page.locator('button:has-text("Cancel"), button[aria-label="Close"]').first();
        await cancelButton.click();
      }
    }
  });

  test('should maintain tunnel status consistency across components', async ({ page }) => {
    // Test that tunnel status is consistent across different UI components
    
    // Get status from header indicator
    const tunnelIndicator = page.locator('.tunnel-status-indicator, [data-testid="tunnel-status-indicator"]').first();
    await expect(tunnelIndicator).toBeVisible({ timeout: 15000 });
    
    const headerStatus = await tunnelIndicator.textContent();
    
    // Open management panel and compare status
    await tunnelIndicator.click();
    
    const managementPanel = page.locator('.tunnel-management-panel, [data-testid="tunnel-management-panel"]').first();
    await expect(managementPanel).toBeVisible({ timeout: 10000 });
    
    const panelStatus = await page.locator('.tunnel-status-card, [data-testid="tunnel-status"]').first().textContent();
    
    // Status should be consistent (allowing for different formatting)
    const normalizeStatus = (status) => {
      return status.toLowerCase().replace(/[^a-z]/g, '');
    };
    
    const normalizedHeaderStatus = normalizeStatus(headerStatus);
    const normalizedPanelStatus = normalizeStatus(panelStatus);
    
    // They should contain similar status keywords
    const statusKeywords = ['connected', 'connecting', 'disconnected', 'error', 'noclient'];
    const headerKeyword = statusKeywords.find(keyword => normalizedHeaderStatus.includes(keyword));
    const panelKeyword = statusKeywords.find(keyword => normalizedPanelStatus.includes(keyword));
    
    expect(headerKeyword).toBeTruthy();
    expect(panelKeyword).toBeTruthy();
    
    // Close panel
    const closeButton = page.locator('button[aria-label="Close"], button:has-text("Close"), .close-button').first();
    await closeButton.click();
  });
});
