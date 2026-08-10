export default function Dashboard() {
  return (
    <div>
      <h1 style={{ color: "#E11D48", marginBottom: 20 }}>Dashboard</h1>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 20 }}>
        {[
          { label: "Total Users", value: "—" },
          { label: "Free Users", value: "—" },
          { label: "Pro Users", value: "—" },
          { label: "Active Devices", value: "—" },
        ].map(card => (
          <div key={card.label} style={{ backgroundColor: "#1a1a1a", padding: 20, borderRadius: 8, border: "1px solid #333" }}>
            <div style={{ color: "#B3B3B3", fontSize: 14 }}>{card.label}</div>
            <div style={{ color: "#E11D48", fontSize: 32, marginTop: 8 }}>{card.value}</div>
          </div>
        ))}
      </div>
    </div>
  )
}
