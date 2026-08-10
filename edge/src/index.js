// Wasmer Edge entry point — delegates to the router.
import router from "./handlers/index.js";

addEventListener("fetch", (fetchEvent) => {
  fetchEvent.respondWith(router.fetch(fetchEvent.request, process.env));
});
