# Multi-stage Docker build for OnlineStatsChains Monitoring Dashboard
# Based on official Julia Docker images

# Stage 1: Build stage
FROM julia:1.10 AS builder

# Set working directory
WORKDIR /app

# Copy Project.toml and Manifest.toml (if exists)
COPY Project.toml ./
COPY Manifest.toml* ./

# Install Julia dependencies
RUN julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

# Stage 2: Runtime stage
FROM julia:1.10-slim

# Install system dependencies (if needed)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create app user for security
RUN useradd -m -s /bin/bash appuser

# Set working directory
WORKDIR /app

# Copy Julia packages from builder
COPY --from=builder /root/.julia /root/.julia

# Copy application files
COPY --chown=appuser:appuser . .

# Ensure correct permissions
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD julia -e 'using HTTP; HTTP.get("http://localhost:8080/") !== nothing || exit(1)'

# Set environment variables
ENV JULIA_PROJECT=/app
ENV GENIE_ENV=prod
ENV PORT=8080
ENV HOST=0.0.0.0

# Run the application
CMD ["julia", "--project=.", "app.jl"]
