/**
 * OnlineStatsChains Viewer - Client-side JavaScript
 * Handles Cytoscape visualization, WebSocket connections, and UI interactions
 */

class DAGViewer {
    constructor(config) {
        this.config = config;
        this.cy = null;
        this.ws = null;
        this.isPaused = false;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        this.reconnectDelay = 2000;

        this.init();
    }

    /**
     * Initialize the viewer
     */
    init() {
        this.initCytoscape();
        this.setupEventHandlers();
        this.updateStats();

        if (this.config.realtime) {
            this.connectWebSocket();
        }
    }

    /**
     * Initialize Cytoscape graph
     */
    initCytoscape() {
        const theme = this.config.theme;
        const nodeColor = theme === 'dark' ? '#4CAF50' : '#2196F3';
        const edgeColor = theme === 'dark' ? '#888888' : '#666666';
        const textColor = theme === 'dark' ? '#ffffff' : '#000000';

        this.cy = cytoscape({
            container: document.getElementById('cy'),
            elements: this.config.elements,

            style: [
                {
                    selector: 'node',
                    style: {
                        'background-color': nodeColor,
                        'label': 'data(label)',
                        'color': textColor,
                        'text-halign': 'center',
                        'text-valign': 'center',
                        'text-wrap': 'wrap',
                        'text-max-width': '100px',
                        'font-size': '12px',
                        'font-weight': '500',
                        'width': '70px',
                        'height': '70px',
                        'border-width': '3px',
                        'border-color': ele => {
                            if (ele.data('is_source')) return '#4CAF50';
                            if (ele.data('is_sink')) return '#2196F3';
                            return edgeColor;
                        },
                        'transition-property': 'background-color, border-color',
                        'transition-duration': '0.3s'
                    }
                },
                {
                    selector: 'edge',
                    style: {
                        'width': ele => {
                            if (ele.data('has_filter') && ele.data('has_transform')) return 4;
                            if (ele.data('has_filter') || ele.data('has_transform')) return 3;
                            return 2;
                        },
                        'line-color': edgeColor,
                        'target-arrow-color': edgeColor,
                        'target-arrow-shape': 'triangle',
                        'arrow-scale': 1.2,
                        'curve-style': 'bezier',
                        'line-style': ele => {
                            if (ele.data('has_filter')) return 'dashed';
                            if (ele.data('has_transform')) return 'dotted';
                            return 'solid';
                        },
                        'transition-property': 'line-color, width',
                        'transition-duration': '0.3s'
                    }
                },
                {
                    selector: ':selected',
                    style: {
                        'background-color': '#FF9800',
                        'line-color': '#FF9800',
                        'target-arrow-color': '#FF9800',
                        'border-color': '#FF9800',
                        'border-width': '4px'
                    }
                },
                {
                    selector: 'node:active',
                    style: {
                        'overlay-color': '#FF9800',
                        'overlay-opacity': 0.2,
                        'overlay-padding': 10
                    }
                }
            ],

            layout: this.getLayoutConfig(),

            // Interaction options
            minZoom: 0.1,
            maxZoom: 5,
            wheelSensitivity: 0.2,
            selectionType: 'single'
        });
    }

    /**
     * Get layout configuration
     */
    getLayoutConfig() {
        const layoutName = this.config.layout;

        const baseConfig = {
            padding: 50,
            animate: true,
            animationDuration: 500,
            fit: true
        };

        switch (layoutName) {
            case 'hierarchical':
            case 'breadthfirst':
                return {
                    name: 'breadthfirst',
                    directed: true,
                    spacingFactor: 1.5,
                    ...baseConfig
                };

            case 'force':
            case 'cose':
                return {
                    name: 'cose',
                    nodeRepulsion: 8000,
                    idealEdgeLength: 100,
                    edgeElasticity: 100,
                    nestingFactor: 1.2,
                    gravity: 1,
                    numIter: 1000,
                    ...baseConfig
                };

            case 'circular':
                return {
                    name: 'circle',
                    ...baseConfig
                };

            case 'grid':
                return {
                    name: 'grid',
                    rows: Math.ceil(Math.sqrt(this.cy.nodes().length)),
                    ...baseConfig
                };

            default:
                return {
                    name: layoutName,
                    ...baseConfig
                };
        }
    }

    /**
     * Setup UI event handlers
     */
    setupEventHandlers() {
        // Node click - show info panel
        this.cy.on('tap', 'node', evt => {
            const node = evt.target;
            this.showNodeInfo(node);
        });

        // Edge click - show info panel
        this.cy.on('tap', 'edge', evt => {
            const edge = evt.target;
            this.showEdgeInfo(edge);
        });

        // Background click - hide info panel
        this.cy.on('tap', evt => {
            if (evt.target === this.cy) {
                this.hideInfoPanel();
            }
        });

        // Button handlers
        document.getElementById('resetBtn').addEventListener('click', () => this.resetView());
        document.getElementById('fitBtn').addEventListener('click', () => this.fitToScreen());
        document.getElementById('exportBtn').addEventListener('click', () => this.exportImage());

        if (this.config.realtime) {
            document.getElementById('pauseBtn').addEventListener('click', () => this.togglePause());
        }

        // Close info panel
        const closeBtn = document.querySelector('#info-panel .close-btn');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => this.hideInfoPanel());
        }

        // Keyboard shortcuts
        document.addEventListener('keydown', evt => {
            if (evt.key === 'Escape') {
                this.hideInfoPanel();
            } else if (evt.key === 'r' && !evt.ctrlKey) {
                this.resetView();
            } else if (evt.key === 'f' && !evt.ctrlKey) {
                this.fitToScreen();
            }
        });
    }

    /**
     * Show node information in side panel
     */
    showNodeInfo(node) {
        const data = node.data();
        const panel = document.getElementById('info-panel');
        const content = document.getElementById('info-content');

        let html = `<h3>📊 Node: ${data.id}</h3>`;

        html += `<div class="info-section">
            <label>Type</label>
            <div class="value">${data.type}</div>
        </div>`;

        if (data.value !== undefined) {
            html += `<div class="info-section">
                <label>Current Value</label>
                <div class="value">${data.value}</div>
            </div>`;
        }

        html += `<div class="info-section">
            <label>Role</label>
            <div class="value">`;

        const roles = [];
        if (data.is_source) roles.push('🔵 Source Node');
        if (data.is_sink) roles.push('🔴 Sink Node');
        if (roles.length === 0) roles.push('⚪ Intermediate Node');

        html += roles.join('<br>');
        html += `</div></div>`;

        // Connections
        const incoming = node.incomers('node').length;
        const outgoing = node.outgoers('node').length;

        html += `<div class="info-section">
            <label>Connections</label>
            <div class="value">
                ↓ Incoming: ${incoming}<br>
                ↑ Outgoing: ${outgoing}
            </div>
        </div>`;

        content.innerHTML = html;
        panel.classList.add('visible');
    }

    /**
     * Show edge information in side panel
     */
    showEdgeInfo(edge) {
        const data = edge.data();
        const panel = document.getElementById('info-panel');
        const content = document.getElementById('info-content');

        let html = `<h3>🔗 Edge</h3>`;

        html += `<div class="info-section">
            <label>Connection</label>
            <div class="value">${data.source} → ${data.target}</div>
        </div>`;

        if (data.has_filter) {
            html += `<div class="info-section">
                <label>🔍 Filter</label>
                <div class="value">${data.filter_str || 'Yes'}</div>
            </div>`;
        }

        if (data.has_transform) {
            html += `<div class="info-section">
                <label>🔄 Transform</label>
                <div class="value">${data.transform_str || 'Yes'}</div>
            </div>`;
        }

        if (!data.has_filter && !data.has_transform) {
            html += `<div class="info-section">
                <label>Type</label>
                <div class="value">Direct connection (no filter or transform)</div>
            </div>`;
        }

        content.innerHTML = html;
        panel.classList.add('visible');
    }

    /**
     * Hide info panel
     */
    hideInfoPanel() {
        document.getElementById('info-panel').classList.remove('visible');
        this.cy.elements().unselect();
    }

    /**
     * Reset view to initial state
     */
    resetView() {
        this.cy.reset();
        this.cy.fit(null, 50);
    }

    /**
     * Fit graph to screen
     */
    fitToScreen() {
        this.cy.fit(null, 50);
    }

    /**
     * Export graph as PNG image
     */
    exportImage() {
        const png = this.cy.png({
            output: 'blob',
            bg: this.config.theme === 'dark' ? '#1e1e1e' : '#ffffff',
            full: true,
            scale: 2
        });

        const url = URL.createObjectURL(png);
        const link = document.createElement('a');
        link.href = url;
        link.download = `dag-${Date.now()}.png`;
        link.click();
        URL.revokeObjectURL(url);
    }

    /**
     * Update statistics display
     */
    updateStats() {
        document.getElementById('nodeCount').textContent = this.cy.nodes().length;
        document.getElementById('edgeCount').textContent = this.cy.edges().length;
    }

    /**
     * Connect to WebSocket for real-time updates
     */
    connectWebSocket() {
        const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${wsProtocol}//${window.location.host}/ws`;

        this.updateConnectionStatus('connecting');

        try {
            this.ws = new WebSocket(wsUrl);

            this.ws.onopen = () => {
                console.log('WebSocket connected');
                this.updateConnectionStatus('connected');
                this.reconnectAttempts = 0;
            };

            this.ws.onmessage = event => {
                if (this.isPaused) return;

                try {
                    const msg = JSON.parse(event.data);
                    this.handleWebSocketMessage(msg);
                } catch (error) {
                    console.error('Failed to parse WebSocket message:', error);
                }
            };

            this.ws.onerror = error => {
                console.error('WebSocket error:', error);
                this.updateConnectionStatus('disconnected');
            };

            this.ws.onclose = () => {
                console.log('WebSocket closed');
                this.updateConnectionStatus('disconnected');
                this.attemptReconnect();
            };

        } catch (error) {
            console.error('Failed to create WebSocket:', error);
            this.updateConnectionStatus('disconnected');
        }
    }

    /**
     * Handle incoming WebSocket messages
     */
    handleWebSocketMessage(msg) {
        switch (msg.type) {
            case 'update':
                this.handleNodeUpdate(msg.data);
                break;

            case 'batch_update':
                msg.data.forEach(update => this.handleNodeUpdate(update));
                break;

            case 'graph_update':
                // Handle structural changes (nodes/edges added/removed)
                this.handleGraphUpdate(msg.data);
                break;

            default:
                console.warn('Unknown message type:', msg.type);
        }
    }

    /**
     * Handle node value update
     */
    handleNodeUpdate(data) {
        const node = this.cy.getElementById(data.node_id);

        if (node.length > 0) {
            // Update value
            node.data('value', data.value);

            // Update label if needed
            const currentLabel = node.data('label');
            if (!currentLabel.includes(': ')) {
                node.data('label', `${data.node_id}: ${data.type}`);
            }

            // Flash animation
            const originalColor = node.style('background-color');
            node.animate({
                style: { 'background-color': '#FF9800' }
            }, {
                duration: 150
            }).delay(150).animate({
                style: { 'background-color': originalColor }
            }, {
                duration: 150
            });
        }
    }

    /**
     * Handle graph structure update
     */
    handleGraphUpdate(data) {
        // TODO: Implement adding/removing nodes and edges dynamically
        console.log('Graph structure update:', data);
    }

    /**
     * Update connection status indicator
     */
    updateConnectionStatus(status) {
        const statusEl = document.getElementById('wsStatus');
        const indicator = document.getElementById('wsIndicator');

        if (!statusEl || !indicator) return;

        indicator.className = `status-indicator ${status}`;

        switch (status) {
            case 'connected':
                statusEl.textContent = 'Connected';
                break;
            case 'connecting':
                statusEl.textContent = 'Connecting...';
                break;
            case 'disconnected':
                statusEl.textContent = 'Disconnected';
                break;
        }
    }

    /**
     * Attempt to reconnect WebSocket
     */
    attemptReconnect() {
        if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            console.error('Max reconnection attempts reached');
            return;
        }

        this.reconnectAttempts++;
        console.log(`Reconnecting... (attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts})`);

        setTimeout(() => {
            this.connectWebSocket();
        }, this.reconnectDelay * this.reconnectAttempts);
    }

    /**
     * Toggle pause state for real-time updates
     */
    togglePause() {
        this.isPaused = !this.isPaused;
        const btn = document.getElementById('pauseBtn');

        if (this.isPaused) {
            btn.textContent = '▶️ Resume';
            btn.classList.add('warning');
        } else {
            btn.textContent = '⏸️ Pause';
            btn.classList.remove('warning');
        }
    }

    /**
     * Close and cleanup
     */
    close() {
        if (this.ws) {
            this.ws.close();
        }
        if (this.cy) {
            this.cy.destroy();
        }
    }
}

// Initialize viewer when DOM is ready
let viewer = null;

document.addEventListener('DOMContentLoaded', () => {
    // Config is injected by server as JSON
    viewer = new DAGViewer(window.viewerConfig);
});

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    if (viewer) {
        viewer.close();
    }
});
