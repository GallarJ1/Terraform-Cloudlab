import express from "express";
import cors from "cors";
import helmet from "helmet";
import sql from "mssql";
import cron from "node-cron";

const app = express();
const port = process.env.PORT || 8080;
const SQL_CONNECTION_STRING = process.env.SQL_CONNECTION_STRING;

async function timed(fn) {
  const t0 = Date.now();
  try { const result = await fn(); return { ok: true, ms: Date.now() - t0, result }; }
  catch (e) { return { ok: false, ms: Date.now() - t0, error: String(e) }; }
}

async function runHealthCheck() {
  const api = await timed(async () => true);
  const db  = await timed(async () => {
    const pool = await sql.connect(SQL_CONNECTION_STRING);
    const res  = await pool.request().query("SELECT DB_NAME() AS DbName;");
    await pool.close();
    return res?.recordset?.[0]?.DbName;
  });

  try {
    const pool = await sql.connect(SQL_CONNECTION_STRING);
    await pool.request()
      .input("ApiOk", sql.Bit, api.ok)
      .input("ApiLatencyMs", sql.Int, api.ms)
      .input("DbOk", sql.Bit, db.ok)
      .input("DbLatencyMs", sql.Int, db.ms)
      .input("DbName", sql.NVarChar(128), db?.result || null)
      .input("ErrorText", sql.NVarChar(2000), api.ok && db.ok ? null : (api.error || db.error || null))
      .query(`
        INSERT INTO dbo.HealthChecks (ApiOk, ApiLatencyMs, DbOk, DbLatencyMs, DbName, ErrorText)
        VALUES (@ApiOk, @ApiLatencyMs, @DbOk, @DbLatencyMs, @DbName, @ErrorText);
      `);
    await pool.close();
  } catch (e) {
    console.error("Failed to save health check:", e);
  }
  return { api, db };
}

// --- routes ---
app.get("/api/ping", (_req, res) => res.json({ ok: true, msg: "pong", at: new Date().toISOString() }));

app.get("/api/dbcheck", async (_req, res) => {
  try {
    const pool = await sql.connect(SQL_CONNECTION_STRING);
    const r = await pool.request().query("SELECT name FROM sys.databases;");
    await pool.close();
    res.json({ ok: true, databases: r.recordset });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

app.get("/api/health", async (_req, res) => {
  try {
    const pool = await sql.connect(SQL_CONNECTION_STRING);
    const r = await pool.request().query(`
      SELECT TOP 50 Id, CheckedAtUtc, ApiOk, ApiLatencyMs, DbOk, DbLatencyMs, ErrorText
      FROM dbo.HealthChecks ORDER BY Id DESC;
    `);
    await pool.close();
    res.json({ ok: true, items: r.recordset.reverse() });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

app.post("/api/health/run", async (_req, res) => {
  const result = await runHealthCheck();
  res.json({ ok: true, result });
});

// background schedule every 5 minutes

app.listen(port, () => console.log(`API listening on ${port}`));
