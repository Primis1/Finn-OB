# Stage 1: Base - Use the latest LTS version of Node.js (20) with a Debian-based slim image
FROM node:20-bullseye-slim AS base

# Stage 2: Dependencies - Install dependencies only when needed
FROM base AS deps
WORKDIR /app

# Install dependencies based on the lockfile found
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi


# Stage 3: Builder - Rebuild the source code
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build the Next.js application
RUN \
  if [ -f yarn.lock ]; then yarn run build; \
  elif [ -f package-lock.json ]; then npm run build; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm run build; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Stage 4: Runner - Production image
FROM base AS runner
WORKDIR /app

# Set production environment variables
ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

# Create a non-root user for security
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy the static assets and the standalone build output
COPY --from=builder /app/public ./public
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Copy the standalone Next.js server and static assets with correct permissions
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Switch to the non-root user
USER nextjs

# Expose the application port
EXPOSE 3000

# Set the port environment variable
ENV PORT 3000

# Start the Next.js server
CMD HOSTNAME="0.0.0.0" node server.js

# The Dockerfile has been updated to use the `node:20-bullseye-slim` image. This version is built on Debian, which provides a familiar environment. The rest of the Dockerfile remains the same as it correctly handles the build and production stag
