# Stage 1: Base image for all subsequent builds
# We're using a specific, stable Node.js version on an Alpine base for a small footprint.
FROM node:22.12.0-alpine AS base

# Stage 2: Install dependencies including those needed for PostgreSQL
FROM base AS deps
# Install essential packages required by Payload's dependencies, especially for `pg-native`
# which needs to compile C++ code to connect to the PostgreSQL database.
RUN apk add --no-cache libc6-compat g++ make python3

# Set the working directory inside the container
WORKDIR /app

# Copy and install dependencies based on the lockfile (pnpm is common for Payload)
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./

RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Stage 3: Build the production application
FROM base AS builder
WORKDIR /app
# Copy installed node_modules from the dependencies stage
COPY --from=deps /app/node_modules ./node_modules
# Copy all of the application's source code
COPY . .

# Next.js collects completely anonymous telemetry data.
# Uncomment the following line in case you want to disable it.
# ENV NEXT_TELEMETRY_DISABLED 1

# Run the build command for your integrated Payload + Next.js app.
# This assumes your `package.json` "build" script handles both the Payload build
# (e.g., `payload build`) and the Next.js build (`next build`).
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

# Switch to the non-root user
USER nextjs

# Expose the port on which your server will run
EXPOSE 3000
ENV PORT 3000

# The command to start your server.
# This assumes your "start" script in `package.json` points to the correct entry file
# of your combined Next.js + Payload server (e.g., `dist/server.js` or similar).
CMD ["npm", "start"]
