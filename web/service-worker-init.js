/**
 * Service Worker Initialization Patch
 * 
 * Fixes the Flutter service worker timeout issue by:
 * 1. Properly handling already-active service workers
 * 2. Implementing robust error handling
 * 3. Preventing the 4000ms timeout when SW is already registered
 */

(function() {
  'use strict';

  // Store original navigator.serviceWorker.register
  const originalRegister = navigator.serviceWorker?.register;
  
  if (!originalRegister) {
    console.debug('[SW Init] Service Worker API not available');
    return;
  }

  // Override register to handle the activation promise correctly
  navigator.serviceWorker.register = async function(scriptURL, options) {
    console.debug('[SW Init] Registering service worker:', scriptURL);
    
    try {
      const registration = await originalRegister.call(this, scriptURL, options);
      console.debug('[SW Init] Service worker registered successfully');
      
      // Ensure the registration object has proper state handling
      if (registration.active) {
        console.debug('[SW Init] Service worker already active');
        return registration;
      }
      
      if (registration.installing || registration.waiting) {
        console.debug('[SW Init] Service worker installing/waiting, waiting for activation...');
        
        // Return a promise that resolves when the SW becomes active
        return new Promise((resolve) => {
          const checkState = () => {
            if (registration.active) {
              console.debug('[SW Init] Service worker activated');
              registration.removeEventListener('updatefound', onUpdateFound);
              resolve(registration);
            }
          };
          
          const onUpdateFound = () => {
            const newWorker = registration.installing;
            if (newWorker) {
              newWorker.addEventListener('statechange', () => {
                if (newWorker.state === 'activated') {
                  console.debug('[SW Init] New service worker activated');
                  registration.removeEventListener('updatefound', onUpdateFound);
                  resolve(registration);
                }
              });
            }
          };
          
          registration.addEventListener('updatefound', onUpdateFound);
          
          // Check immediately in case it's already active
          checkState();
          
          // Set a reasonable timeout to prevent hanging
          setTimeout(() => {
            console.warn('[SW Init] Service worker activation timeout, but continuing anyway');
            registration.removeEventListener('updatefound', onUpdateFound);
            resolve(registration);
          }, 2000);
        });
      }
      
      return registration;
    } catch (error) {
      console.error('[SW Init] Service worker registration failed:', error);
      // Don't throw - let the app continue without SW
      return null;
    }
  };

  console.debug('[SW Init] Service worker initialization patch loaded');
})();
