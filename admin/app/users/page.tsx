export default function Users() {
  return (
    <div>
      <h1 style={{ color: "#E11D48", marginBottom: 20 }}>Users</h1>
      <div style={{ backgroundColor: "#1a1a1a", borderRadius: 8, border: "1px solid #333", overflow: "hidden" }}>
        <table style={{ width: "100%", borderCollapse: "collapse" }}>
          <thead>
            <tr style={{ borderBottom: "1px solid #333" }}>
              <th style={{ padding: 12, textAlign: "left", color: "#B3B3B3" }}>Email</th>
              <th style={{ padding: 12, textAlign: "left", color: "#B3B3B3" }}>Tier</th>
              <th style={{ padding: 12, textAlign: "left", color: "#B3B3B3" }}>Admin</th>
              <th style={{ padding: 12, textAlign: "left", color: "#B3B3B3" }}>Joined</th>
            </tr>
          </thead>
          <tbody>
            <tr style={{ borderBottom: "1px solid #222" }}>
              <td style={{ padding: 12, color: "#fff" }}>Connect Supabase to populate</td>
              <td style={{ padding: 12, color: "#B3B3B3" }}>—</td>
              <td style={{ padding: 12, color: "#B3B3B3" }}>—</td>
              <td style={{ padding: 12, color: "#B3B3B3" }}>—</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  )
}
