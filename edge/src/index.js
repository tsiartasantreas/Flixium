// Minimal test handler — just return a JSON response
addEventListener("fetch", (fetchEvent) => {
  fetchEvent.respondWith(
    new Response(JSON.stringify({ status: "ok", env: process.env }), {
      headers: { "Content-Type": "application/json" },
    })
  );
});
