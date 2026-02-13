/**
 * Singularity DB Client
 * Drop this into any HTML file. Zero config.
 * 
 * Usage:
 *   const db = new SingularityDB("my-app-name");
 *   await db.set("users/alice", { name: "Alice", role: "builder" });
 *   const user = await db.get("users/alice");
 *   const allKeys = await db.list();
 *   await db.delete("users/alice");
 */
class SingularityDB {
  constructor(namespace, apiUrl) {
    this.namespace = namespace;
    this.apiUrl = apiUrl || "YOUR_SINGULARITY_DB_API_URL";
  }

  async get(key) {
    const res = await fetch(`${this.apiUrl}/${this.namespace}/${key}`);
    if (res.status === 404) return null;
    const data = await res.json();
    return data.value;
  }

  async set(key, value) {
    const res = await fetch(`${this.apiUrl}/${this.namespace}/${key}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ value }),
    });
    return res.json();
  }

  async delete(key) {
    const res = await fetch(`${this.apiUrl}/${this.namespace}/${key}`, {
      method: "DELETE",
    });
    return res.json();
  }

  async list() {
    const res = await fetch(`${this.apiUrl}/${this.namespace}`);
    return res.json();
  }
}

// Export for module use, also attach to window for script tag use
if (typeof module !== "undefined") module.exports = SingularityDB;
if (typeof window !== "undefined") window.SingularityDB = SingularityDB;
