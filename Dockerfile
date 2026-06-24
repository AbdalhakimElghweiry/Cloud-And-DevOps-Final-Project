# Stage 1: install production dependencies in a clean layer
FROM node:20-alpine AS deps
WORKDIR /app
COPY app/package*.json ./
RUN npm install --production --ignore-scripts

# Stage 2: minimal runtime image
FROM node:20-alpine AS runtime
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY app/ ./
EXPOSE 3000
USER node
CMD ["node", "index.js"]
