/** @type {import('next').NextConfig} */
const nextConfig = {
  // Wasmer Edge serves the admin panel as a static site (spec §10).
  output: 'export',
  reactStrictMode: true,
};

export default nextConfig;
