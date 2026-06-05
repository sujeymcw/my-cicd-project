# --- Stage 1: Build the Expo Web Assets ---
# FIX: Upgraded from node:18 to node:20 to natively support .toReversed() and current Expo requirements
FROM node:20 AS builder

WORKDIR /app

# Copy dependency files first from the clean src directory
COPY src/package*.json ./

# Clean cache and install dependencies with legacy peer resolution to prevent crashes
RUN npm cache clean --force && npm install --legacy-peer-deps

# Copy the rest of your Expo source files
COPY src/ .

# Disable telemetry and interactive prompts, then force export
ENV CI=true
ENV EXPO_TELEMETRY_OPT_OUT=1
RUN npx expo export --platform web --clear

# --- Stage 2: Serve with NGINX ---
FROM nginx:alpine

# Copy the compiled static web files from the builder stage to NGINX
COPY --from=builder /app/dist /usr/share/nginx/html

# Expose port 80 to match your Helm service configurations
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]