import type { NextConfig } from 'next';
// Vinext beta.5 prerender requests /en without a slash; trailingSlash:true
// redirects that request instead of rendering it. The Pages copy maps en.html
// to en/index.html, preserving the public canonical /ProfileDock/en/ URL.
const nextConfig: NextConfig = { output: 'export', assetPrefix: '/ProfileDock' };
export default nextConfig;
