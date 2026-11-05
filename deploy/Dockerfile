FROM node:24.22.1-bookworm-slim
ENV NODE_ENV=production PORT=8798 HOST=0.0.0.0 DATA_DIR=/data WEB_DIR=/app/web
WORKDIR /app/server
COPY server/package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --chown=node:node server/ ./
RUN mkdir -p /data /app/web && chown node:node /data /app/web
USER node
EXPOSE 8798
CMD ["npm", "start"]
