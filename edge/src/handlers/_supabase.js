// Lightweight Supabase REST client for Wasmer Edge (no Node built-ins).
// Uses the PostgREST API directly via fetch.

export function createClient(env) {
  const url = env.SUPABASE_URL; // e.g. https://zosckkklctvrsjqjmyiv.supabase.co
  const key = env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !key) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars");
  }

  function headers(extra = {}) {
    return {
      apikey: key,
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
      ...extra,
    };
  }

  return {
    from(table) {
      return new QueryBuilder(url, key, table, headers);
    },
  };
}

class QueryBuilder {
  constructor(url, key, table, headersFn) {
    this._url = url;
    this._key = key;
    this._table = table;
    this._headers = headersFn;
    this._filters = [];
    this._select = null;
    this._single = false;
    this._countOpts = null;
  }

  select(cols = "*", opts = {}) {
    this._select = cols;
    if (opts.count === "exact" && opts.head) {
      this._countOpts = { count: "exact", head: true };
    }
    return this;
  }

  eq(col, val) {
    this._filters.push(`${col}=eq.${encodeURIComponent(val)}`);
    return this;
  }

  single() {
    this._single = true;
    return this;
  }

  _buildUrl() {
    let base = `${this._url}/rest/v1/${this._table}`;
    const params = [];

    if (this._select) {
      params.push(`select=${encodeURIComponent(this._select)}`);
    }

    if (this._filters.length) {
      params.push(...this._filters);
    }

    // Head request for count-only queries
    if (this._countOpts?.head) {
      params.push(`limit=0`);
    }

    if (params.length) {
      base += "?" + params.join("&");
    }

    return base;
  }

  async insert(row) {
    const res = await fetch(this._buildUrl(), {
      method: "POST",
      headers: this._headers({ Prefer: "return=representation" }),
      body: JSON.stringify(row),
    });
    const data = await res.json();
    if (res.status >= 400) {
      return { data: null, error: { message: data?.message || "insert failed", status: res.status } };
    }
    return { data, error: null };
  }

  async upsert(row, opts = {}) {
    const hdrs = this._headers({ Prefer: "return=representation" });
    if (opts.onConflict) {
      // PostgREST on_conflict is only for columns; we send it as a query param
    }
    let url = this._buildUrl();
    if (opts.onConflict) {
      url += (url.includes("?") ? "&" : "?") + `on_conflict=${encodeURIComponent(opts.onConflict)}`;
    }
    const res = await fetch(url, {
      method: "POST",
      headers: hdrs,
      body: JSON.stringify(row),
    });
    const data = await res.json();
    if (res.status >= 400) {
      return { data: null, error: { message: data?.message || "upsert failed", status: res.status } };
    }
    return { data, error: null };
  }

  update(updates) {
    this._updates = updates;
    return this;
  }

  // Executes the query and returns { data, error, count }
  async then(resolve) {
    const url = this._buildUrl();
    const isHead = !!this._countOpts?.head;
    const isUpdate = !!this._updates;

    const res = await fetch(url, {
      method: isUpdate ? "PATCH" : "GET",
      headers: this._headers(
        isUpdate
          ? { Prefer: "return=representation" }
          : isHead
            ? { Prefer: "count=exact" }
            : this._countOpts
              ? { Prefer: "count=exact" }
              : undefined,
      ),
      ...(isUpdate ? { body: JSON.stringify(this._updates) } : {}),
    });

    if (isHead) {
      const count = parseInt(res.headers.get("content-range")?.split("/")[1] || "0", 10);
      resolve({ data: null, error: null, count });
      return;
    }

    const data = await res.json();
    if (res.status >= 400) {
      resolve({ data: null, error: { message: data?.message || "query failed", status: res.status }, count: null });
      return;
    }

    if (this._single) {
      const row = Array.isArray(data) ? data[0] : data;
      resolve({ data: row || null, error: null, count: null });
      return;
    }

    resolve({ data, error: null, count: null });
  }
}
