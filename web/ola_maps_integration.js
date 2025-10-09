// OLA Maps Web Integration for Campus Ride
(function() {
    'use strict';

    // Wait for Flutter to initialize
    window.addEventListener('DOMContentLoaded', function() {
        // Register the OLA Maps view factory
        if (window.flutterWebRenderer) {
            console.log('Registering OLA Maps web view...');
            
            // This will be called when Flutter creates an HtmlElementView
            window.olaMapViewFactory = function(viewId, params) {
                console.log('Creating OLA Maps view:', viewId, params);
                
                const container = document.createElement('div');
                container.style.width = '100%';
                container.style.height = '100%';
                container.style.position = 'relative';
                container.style.overflow = 'hidden';
                container.style.borderRadius = '8px';
                container.style.backgroundColor = '#f5f5f5';
                
                // Create iframe for OLA Maps
                const iframe = document.createElement('iframe');
                iframe.src = 'ola_maps.html';
                iframe.style.width = '100%';
                iframe.style.height = '100%';
                iframe.style.border = 'none';
                iframe.style.borderRadius = '8px';
                
                // Send route data to iframe when ready
                iframe.onload = function() {
                    if (params) {
                        iframe.contentWindow.postMessage({
                            type: 'DISPLAY_ROUTE',
                            data: params
                        }, '*');
                    }
                };
                
                container.appendChild(iframe);
                
                // Add loading indicator
                const loadingDiv = document.createElement('div');
                loadingDiv.style.position = 'absolute';
                loadingDiv.style.top = '50%';
                loadingDiv.style.left = '50%';
                loadingDiv.style.transform = 'translate(-50%, -50%)';
                loadingDiv.style.color = '#666';
                loadingDiv.style.fontSize = '14px';
                loadingDiv.innerHTML = '🗺️ Loading OLA Maps...';
                
                container.appendChild(loadingDiv);
                
                // Remove loading indicator after iframe loads
                iframe.addEventListener('load', function() {
                    setTimeout(function() {
                        if (loadingDiv.parentNode) {
                            loadingDiv.parentNode.removeChild(loadingDiv);
                        }
                    }, 1000);
                });
                
                return container;
            };
        }
    });

    // Listen for messages from Flutter
    window.addEventListener('message', function(event) {
        if (event.data && event.data.type === 'OLA_MAPS_UPDATE') {
            console.log('Received OLA Maps update:', event.data);
            // Forward to all OLA Maps iframes
            const iframes = document.querySelectorAll('iframe[src="ola_maps.html"]');
            iframes.forEach(function(iframe) {
                iframe.contentWindow.postMessage(event.data, '*');
            });
        }
    });

})();