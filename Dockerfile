FROM mcr.microsoft.com/playwright:v1.49.0-noble

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY watcher.mjs ./

ENV PORT=3000

CMD ["node", "watcher.mjs"]
