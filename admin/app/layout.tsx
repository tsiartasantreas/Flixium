import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Flixium Admin",
  description: "Admin panel for Flixium",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body style={{ backgroundColor: "#141414", color: "#FFFFFF", margin: 0, fontFamily: "system-ui, sans-serif" }}>
        {children}
      </body>
    </html>
  );
}
