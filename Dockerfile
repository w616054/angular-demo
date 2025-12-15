# Build stage
FROM node:20-alpine AS build
WORKDIR /app
# Use pnpm (match local dev) for faster, reproducible installs
RUN corepack enable
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .
RUN pnpm run build

# Production stage
FROM nginx:1.29.0-alpine
# Copy the built SPA assets into nginx web root (so /index.html replaces nginx default page)
COPY --from=build /app/dist/angular-k8s-demo/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
