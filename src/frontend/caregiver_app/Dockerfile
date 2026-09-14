# ==========================================
# 1. Build Stage
# ==========================================
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies
COPY package.json package-lock.json ./
RUN npm ci || npm install

# Copy application source
COPY . .

# Build argument to configure API endpoint at build time
ARG VITE_API_URL=http://fedora:8000
ENV VITE_API_URL=${VITE_API_URL}

# Build optimized static assets
RUN npm run build

# ==========================================
# 2. Production Stage (Nginx)
# ==========================================
FROM nginx:alpine AS production

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy built static files from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 5173
EXPOSE 5173

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
