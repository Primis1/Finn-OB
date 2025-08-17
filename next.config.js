import { withPayload } from '@payloadcms/next/withPayload'

import redirects from './redirects.js'

const NEXT_PUBLIC_SERVER_URL = process.env.VERCEL_PROJECT_PRODUCTION_URL
  ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
  : undefined || process.env.__NEXT_PRIVATE_ORIGIN || 'http://localhost:3000'

/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      // Keep existing production URL handling
      ...(NEXT_PUBLIC_SERVER_URL ? [{
        hostname: new URL(NEXT_PUBLIC_SERVER_URL).hostname,
        protocol: new URL(NEXT_PUBLIC_SERVER_URL).protocol.replace(':', ''),
      }] : []),

      // Add local network testing configurations
      {
        hostname: 'localhost',
        protocol: 'http',
        port: '3000'
      },
      {
        hostname: '192.168.4.32', // Your local IP
        protocol: 'http',
        port: '3000'
      },

      {
        hostname: 'finn-ob.ca',
        protocol: 'http',

      }
    ],
  },
  webpack: (webpackConfig) => {
    webpackConfig.resolve.extensionAlias = {
      '.cjs': ['.cts', '.cjs'],
      '.js': ['.ts', '.tsx', '.js', '.jsx'],
      '.mjs': ['.mts', '.mjs'],
    }

    return webpackConfig
  },
  reactStrictMode: true,
  redirects,
}

export default withPayload(nextConfig, { devBundleServerPackages: false })
