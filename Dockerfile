# --- Stage 1: Build Expo Web App ---
FROM node:20 AS builder

WORKDIR /app

# Copy package files from src folder
COPY src/package*.json ./

# Install dependencies
RUN npm cache clean --force && npm install --legacy-peer-deps

# Copy Expo source code
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