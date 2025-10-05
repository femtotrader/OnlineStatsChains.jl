// SIMPLE Cytoscape integration - no bullshit version
console.log('[Cytoscape] Script loaded');

let cy = null;

function initCytoscape() {
    console.log('[Cytoscape] Starting initialization...');

    // Check if Cytoscape library is loaded
    if (typeof cytoscape === 'undefined') {
        console.log('[Cytoscape] Library not loaded, retrying in 500ms...');
        setTimeout(initCytoscape, 500);
        return;
    }

    // Get the data element
    const dataDiv = document.getElementById('cyto-data');
    if (!dataDiv) {
        console.log('[Cytoscape] Data div not found, retrying in 500ms...');
        setTimeout(initCytoscape, 500);
        return;
    }

    // Get the container element
    const container = document.getElementById('cy');
    if (!container) {
        console.log('[Cytoscape] Container not found, retrying in 500ms...');
        setTimeout(initCytoscape, 500);
        return;
    }

    const rawData = dataDiv.textContent.trim();
    console.log('[Cytoscape] Raw data:', rawData);

    if (!rawData || rawData === '{}') {
        console.log('[Cytoscape] No data yet, retrying in 500ms...');
        setTimeout(initCytoscape, 500);
        return;
    }

    try {
        const data = JSON.parse(rawData);
        console.log('[Cytoscape] Parsed data:', data);
        console.log('[Cytoscape] Nodes count:', data.nodes ? data.nodes.length : 0);
        console.log('[Cytoscape] Edges count:', data.edges ? data.edges.length : 0);

        // Destroy existing instance
        if (cy) {
            cy.destroy();
        }

        // Create Cytoscape instance
        cy = cytoscape({
            container: container,

            elements: {
                nodes: data.nodes || [],
                edges: data.edges || []
            },

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

        console.log('[Cytoscape] ✓✓✓ SUCCESS! Graph created with', cy.nodes().length, 'nodes');

        // Setup periodic updates
        setInterval(updateGraph, 2000);

    } catch (e) {
        console.error('[Cytoscape] ERROR:', e);
        setTimeout(initCytoscape, 1000);
    }
}

function updateGraph() {
    if (!cy) return;

    const dataDiv = document.getElementById('cyto-data');
    if (!dataDiv) return;

    const rawData = dataDiv.textContent.trim();
    if (!rawData || rawData === '{}') return;

    try {
        const data = JSON.parse(rawData);
        cy.elements().remove();
        cy.add(data.nodes);
        cy.add(data.edges);
        cy.layout({
            name: 'breadthfirst',
            directed: true,
            padding: 10,
            spacingFactor: 1.5
        }).run();
    } catch (e) {
        console.error('[Cytoscape] Update error:', e);
    }
}

// Start when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        console.log('[Cytoscape] DOM ready');
        setTimeout(initCytoscape, 1000);
    });
} else {
    console.log('[Cytoscape] DOM already ready');
    setTimeout(initCytoscape, 1000);
}
