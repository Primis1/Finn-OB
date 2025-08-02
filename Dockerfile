# Stage 1: Base image for all subsequent builds
# We're using a specific, stable Node.js version on an Alpine base for a small footprint.
FROM node:22.12.0-alpine AS base

# Stage 2: Install dependencies including those needed for PostgreSQL
FROM base AS deps
# Install essential packages required by Payload's dependencies, especially for `pg-native`
# which needs to compile C++ code to connect to the PostgreSQL database.
# CHANGE: Added `nodejs` here as a fail-safe to ensure npm is available.
RUN apk add --no-cache libc6-compat g++ make python3 nodejs

# Set the working directory inside the container
WORKDIR /app

# Copy the package.json and package-lock.json to install dependencies
COPY package.json package-lock.json ./

# CHANGE: Update npm to a newer version to better handle dependency conflicts.
# This should fix the ERESOLVE error.
RUN npm install -g npm@11.5.2

# CHANGE: Using --legacy-peer-deps to force the installation.
# This tells npm to ignore peer dependency conflicts like the one between
# lucide-react and react.
RUN npm install --legacy-peer-deps

# Stage 3: Build the production application
FROM base AS builder
WORKDIR /app
# Copy the entire application folder from the 'deps' stage.
# This ensures a consistent file structure with all dependencies and source code.
COPY --from=deps /app ./

# Next.js collects completely anonymous telemetry data.
# Uncomment the following line in case you want to disable it.
# ENV NEXT_TELEMETRY_DISABLED 1

# Run the build command for your integrated Payload + Next.js app.
# This assumes your `package.json` "build" script handles both the Payload build
# (e.g., `payload build`) and the Next.js build (`next build`).
RUN npm run build

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
