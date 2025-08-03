
FROM node:22.12.0-alpine AS base

FROM base AS deps
RUN apk add --no-cache libc6-compat g++ make python3 nodejs

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm install -g npm@11.5.2

RUN npm install --legacy-peer-deps

# Stage 3: Build the production application
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED 1

RUN \
  if [ -f yarn.lock ]; then yarn run build; \
  elif [ -f package-lock.json ]; then npm run build; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm run build; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Stage 4: Create the final, lightweight production image
FROM base AS runner
WORKDIR /app

# Set production environment and disable Next.js telemetry if desired
ENV NODE_ENV production
# ENV NEXT_TELEMETRY_DISABLED 1

# Create a non-root user for security best practices
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy the entire built application from the builder stage
# The `--chown` flag ensures the files are owned by our non-root user.
COPY --from=builder --chown=nextjs:nodejs /app ./

# Set the correct permissions for the .next directory and any other cache files
RUN chown -R nextjs:nodejs .next

# --- ADD THESE LINES --- #
# Create the media directory and set ownership for the non-root user
RUN mkdir -p /app/media
RUN chown -R nextjs:nodejs /app/media
# ----------------------- #

# Switch to the non-root user
USER nextjs

# Expose the port on which your server will run
EXPOSE 3000
ENV PORT 3000

# The command to start your server.
# This assumes your "start" script in `package.json` points to the correct entry file
# of your combined Next.js + Payload server (e.g., `dist/server.js` or similar).
CMD ["npm", "start"]
