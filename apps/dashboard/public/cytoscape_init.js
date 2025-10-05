console.log('[Cytoscape] External script loaded!');

function initCytoscape() {
    console.log('[Cytoscape] Initializing...');

    if (typeof cytoscape === 'undefined') {
        console.log('[Cytoscape] Cytoscape library not loaded, waiting...');
        setTimeout(initCytoscape, 500);
        return;
    }

    const dataDiv = document.getElementById('cyto-data');
    const container = document.getElementById('cy');

    if (!dataDiv || !container) {
        console.log('[Cytoscape] DOM elements not found, waiting...');
        setTimeout(initCytoscape, 500);
        return;
    }

    const rawData = dataDiv.textContent.trim();
    console.log('[Cytoscape] Data present:', rawData.length > 0);

    if (!rawData || rawData === '{}') {
        console.log('[Cytoscape] No valid data yet, waiting...');
        setTimeout(initCytoscape, 500);
        return;
    }

    try {
        const data = JSON.parse(rawData);
        console.log('[Cytoscape] Parsed successfully! Nodes:', data.nodes.length, 'Edges:', data.edges.length);

        if (window.cy) {
            window.cy.destroy();
        }

        window.cy = cytoscape({
            container: container,
            elements: data,
            style: [
                {
                    selector: 'node',
                    style: {
                        'background-color': '#2196f3',
                        'label': 'data(label)',
                        'text-valign': 'center',
                        'text-halign': 'center',
                        'color': '#000',
                        'width': 80,
                        'height': 80,
                        'font-size': '11px',
                        'text-wrap': 'wrap'
                    }
                },
                {
                    selector: 'edge',
                    style: {
                        'width': 3,
                        'line-color': '#999',
                        'target-arrow-color': '#999',
                        'target-arrow-shape': 'triangle',
                        'curve-style': 'bezier'
                    }
                }
            ],
            layout: {
                name: 'breadthfirst',
                directed: true,
                padding: 10,
                spacingFactor: 1.5
            }
        });

        console.log('[Cytoscape] ✓✓✓ GRAPH CREATED SUCCESSFULLY ✓✓✓');
        console.log('[Cytoscape] Graph has', window.cy.nodes().length, 'nodes');

    } catch (e) {
        console.error('[Cytoscape] ERROR creating graph:', e);
        setTimeout(initCytoscape, 1000);
    }
}

// Start initialization when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
        console.log('[Cytoscape] DOM ready, starting in 2 seconds...');
        setTimeout(initCytoscape, 2000);
    });
} else {
    console.log('[Cytoscape] DOM already ready, starting in 2 seconds...');
    setTimeout(initCytoscape, 2000);
}
