import "./globals.css"

export const metadata = {
  title: "iFlixify Admin",
  description: "Admin panel for iFlixify IPTV",
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body style={{ backgroundColor: "#141414", color: "#fff", fontFamily: "system-ui", margin: 0 }}>
        <div style={{ display: "flex", minHeight: "100vh" }}>
          <nav style={{ width: 200, backgroundColor: "#1a1a1a", padding: 20, borderRight: "1px solid #333" }}>
            <h2 style={{ color: "#E11D48", fontSize: 18 }}>iFlixify Admin</h2>
            <ul style={{ listStyle: "none", padding: 0 }}>
              {["Dashboard", "Users", "Subscriptions", "Devices", "Feature Flags", "Audit Log"].map(item => (
                <li key={item} style={{ padding: "8px 0", color: "#B3B3B3" }}>{item}</li>
              ))}
            </ul>
          </nav>
          <main style={{ flex: 1, padding: 30 }}>{children}</main>
        </div>
      </body>
    </html>
  )
}
