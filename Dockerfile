# --- Stage 1: Build the Expo Web Assets ---
FROM node:18-alpine AS builder

WORKDIR /app

# Copy dependency files first from the clean src directory
COPY src/package*.json ./
RUN npm install

# Copy the rest of your Expo source files
COPY src/ .

# Force a clean, non-interactive production export build
ENV CI=true
RUN npx expo export --platform web --clear

# --- Stage 2: Serve with NGINX ---
FROM nginx:alpine

# Copy the compiled static web files from the builder stage to NGINX
COPY --from=builder /app/dist /usr/share/nginx/html

# Expose port 80 to match your Helm service configurations
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]