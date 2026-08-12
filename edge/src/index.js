// Wasmer Edge entry point — WinterCG fetch handler.
// Delegates to the router in handlers/index.js.
import router from "./handlers/index.js";

export default {
  async fetch(request, env) {
    return router.fetch(request, env);
  },
};
