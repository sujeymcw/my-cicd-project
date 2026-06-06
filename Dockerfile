# --- Stage 1: Build Expo Web App ---
FROM node:20 AS builder

WORKDIR /app

# Copy package files from src folder first to lock down cache layers
COPY src/package*.json ./

# Install dependencies (This step will now take 0 seconds on subsequent runs!)
RUN npm cache clean --force && npm install --legacy-peer-deps

# Copy the rest of your Expo source code AFTER dependencies are cached
COPY src/ .

# Expo settings
ENV CI=true
ENV EXPO_TELEMETRY_OPT_OUT=1

# Build Expo web output
RUN npx expo export --platform web --clear


# --- Stage 2: Serve using Nginx ---
FROM nginx:alpine

# Copy exported dist folder to nginx html folder
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]