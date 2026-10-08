"use client";

import { useCallback, useEffect, useMemo, useState, useSyncExternalStore } from "react";
import { supabase } from "../site";

type Code = {
  id: string;
  code: string;
  is_used: boolean;
  used_at: string | null;
  device_id: string | null;
  created_at: string;
  /** Set when the code was released for transfer to another device. */
  released_at?: string | null;
  transfer_count?: number;
};

const TOKEN_KEY = "a320_admin_token";

class RpcError extends Error {}

/** Calls a Supabase RPC function with the publishable key. */
async function rpc<T>(fn: string, args: Record<string, unknown>): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`${supabase.url}/rest/v1/rpc/${fn}`, {
      method: "POST",
      headers: { apikey: supabase.key, "Content-Type": "application/json" },
      body: JSON.stringify(args),
    });
  } catch {
    throw new RpcError("NETWORK");
  }
  const text = await res.text();
  if (!res.ok) {
    if (res.status === 404) throw new RpcError("NOT_SET_UP");
    throw new RpcError(text.includes("NOT_AUTHORIZED") ? "NOT_AUTHORIZED" : "SERVER");
  }
  return (text ? JSON.parse(text) : null) as T;
}

const errorText: Record<string, string> = {
  INVALID: "Wrong username or password.",
  TOO_MANY_ATTEMPTS: "Too many attempts. Please wait 15 minutes.",
  NETWORK: "No connection to the server.",
  NOT_SET_UP: "The database is not set up yet. Run the setup SQL in Supabase.",
  SERVER: "Server error. Please try again.",
  WRONG_PASSWORD: "Current password is wrong.",
  TOO_SHORT: "Username needs 3+ characters and password 8+ characters.",
  NOT_USED: "That code is no longer active on a device (already released). Reload the page.",
};

function fmt(d: string | null) {
  return d ? new Date(d).toLocaleString() : "—";
}

const tokenListeners = new Set<() => void>();
let memoryToken: string | null = null; // used when storage is blocked

function readToken(): string | null {
  try {
    return sessionStorage.getItem(TOKEN_KEY);
  } catch {
    return memoryToken;
  }
}

function writeToken(t: string | null) {
  memoryToken = t;
  try {
    if (t) sessionStorage.setItem(TOKEN_KEY, t);
    else sessionStorage.removeItem(TOKEN_KEY);
  } catch {
    /* storage blocked: keep it in memory */
  }
  tokenListeners.forEach((l) => l());
}

function subscribeToken(l: () => void) {
  tokenListeners.add(l);
  return () => tokenListeners.delete(l);
}

export default function AdminPage() {
  // undefined during the static (server) render, then the stored token.
  const token = useSyncExternalStore<string | null | undefined>(
    subscribeToken,
    readToken,
    () => undefined,
  );
  const ready = token !== undefined;
  const saveToken = writeToken;

  return (
    <div className="radar min-h-screen">
      <header className="mx-auto flex max-w-6xl items-center gap-3 px-4 py-5 sm:px-8">
        <span className="grid size-10 place-items-center rounded-xl border-2 border-cyan/60 font-mono text-sm font-extrabold text-cyan">
          OI
        </span>
        <span className="text-sm font-extrabold tracking-[0.25em]">
          OVERDRIVE INTERACTIVE
          <span className="ml-2 font-mono text-[10px] tracking-[0.3em] text-cyan">ADMIN</span>
        </span>
        {token && (
          <button
            onClick={async () => {
              try {
                await rpc("a320_admin_logout", { p_token: token });
              } catch {
                /* ignore */
              }
              saveToken(null);
            }}
            className="ml-auto rounded-lg border border-line px-4 py-2 text-sm font-bold text-silver hover:text-white"
          >
            Log out
          </button>
        )}
      </header>
      <main className="mx-auto max-w-6xl px-4 pb-16 sm:px-8">
        {!ready ? null : token ? (
          <Dashboard token={token} onExpired={() => saveToken(null)} />
        ) : (
          <Login onLogin={saveToken} />
        )}
      </main>
    </div>
  );
}

function Login({ onLogin }: { onLogin: (t: string) => void }) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const r = await rpc<{ ok: boolean; token?: string; reason?: string }>(
        "a320_admin_login",
        { p_username: username.trim(), p_password: password },
      );
      if (r.ok && r.token) onLogin(r.token);
      else setError(errorText[r.reason ?? "SERVER"] ?? errorText.SERVER);
    } catch (err) {
      setError(errorText[(err as Error).message] ?? errorText.SERVER);
    } finally {
      setBusy(false);
    }
  };

  return (
    <form
      onSubmit={submit}
      className="mx-auto mt-16 max-w-sm rounded-2xl border border-line bg-panel/80 p-7"
    >
      <h1 className="text-2xl font-extrabold">Admin login</h1>
      <p className="mt-1 text-sm text-silver">A320 FAP Simulator · license codes</p>
      <label className="mt-6 block text-xs font-bold tracking-wider text-silver">
        USERNAME
        <input
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          autoComplete="username"
          required
          className="mt-1 w-full rounded-lg border border-line bg-ink px-3 py-3 text-base text-white outline-none focus:border-cyan"
        />
      </label>
      <label className="mt-4 block text-xs font-bold tracking-wider text-silver">
        PASSWORD
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoComplete="current-password"
          required
          className="mt-1 w-full rounded-lg border border-line bg-ink px-3 py-3 text-base text-white outline-none focus:border-cyan"
        />
      </label>
      {error && <p className="mt-4 text-sm font-bold text-fap-red">{error}</p>}
      <button
        disabled={busy}
        className="mt-6 w-full rounded-xl bg-cyan py-3 font-extrabold tracking-wider text-black hover:brightness-110 disabled:opacity-50"
      >
        {busy ? "Signing in…" : "SIGN IN"}
      </button>
    </form>
  );
}

function Dashboard({ token, onExpired }: { token: string; onExpired: () => void }) {
  const [codes, setCodes] = useState<Code[] | null>(null);
  const [query, setQuery] = useState("");
  const [message, setMessage] = useState<{ text: string; ok: boolean } | null>(null);
  const [busy, setBusy] = useState(false);

  const fail = useCallback(
    (err: unknown) => {
      const code = (err as Error).message;
      if (code === "NOT_AUTHORIZED") {
        onExpired();
        return;
      }
      setMessage({ text: errorText[code] ?? errorText.SERVER, ok: false });
    },
    [onExpired],
  );

  const [version, setVersion] = useState(0);
  const load = useCallback(() => setVersion((v) => v + 1), []);

  useEffect(() => {
    let alive = true;
    rpc<Code[]>("a320_admin_list_codes", { p_token: token })
      .then((rows) => {
        if (alive) setCodes(rows);
      })
      .catch((err) => {
        if (alive) fail(err);
      });
    return () => {
      alive = false;
    };
  }, [token, fail, version]);

  const act = async (fn: () => Promise<unknown>, done: string) => {
    setBusy(true);
    setMessage(null);
    try {
      await fn();
      setMessage({ text: done, ok: true });
      load();
    } catch (err) {
      fail(err);
    } finally {
      setBusy(false);
    }
  };

  // Released codes wait for their owner: not part of the 10 fresh codes.
  const unused = useMemo(
    () => (codes ?? []).filter((c) => !c.is_used && !c.released_at),
    [codes],
  );
  // Transferred: released at least once (waiting for the owner's new
  // device, or already active on it). Shown apart from first-time codes.
  const transferred = useMemo(
    () => (codes ?? []).filter((c) => (c.transfer_count ?? 0) > 0 || !!c.released_at),
    [codes],
  );
  const used = useMemo(
    () => (codes ?? []).filter((c) => c.is_used && !((c.transfer_count ?? 0) > 0)),
    [codes],
  );
  const usedShown = useMemo(
    () => used.filter((c) => c.code.includes(query.trim())),
    [used, query],
  );

  const copyBtn = (code: string) => (
    <button
      onClick={() =>
        navigator.clipboard
          ?.writeText(code)
          .then(() => setMessage({ text: `${code} copied.`, ok: true }))
      }
      className="rounded-md border border-line px-2 py-1 text-xs font-bold text-silver hover:text-white"
    >
      Copy
    </button>
  );
  const releaseBtn = (c: Code) => (
    <button
      disabled={busy}
      onClick={() => {
        if (
          !confirm(
            `Release ${c.code}? It will be unbound from its device and can be activated on a new device. Give it back only to the same owner.`,
          )
        )
          return;
        act(async () => {
          const r = await rpc<{ ok: boolean }>("a320_admin_release_code", {
            p_token: token,
            p_id: c.id,
          });
          if (!r?.ok) throw new RpcError("NOT_USED");
        }, `${c.code} was released. The owner can activate it on a new device.`);
      }}
      className="rounded-md border border-cyan/50 px-2 py-1 text-xs font-bold text-cyan disabled:opacity-50"
    >
      Release
    </button>
  );
  const emptyRow = (text: string, cols = 4) => (
    <tr>
      <td colSpan={cols} className="py-6 text-center text-silver">
        {text}
      </td>
    </tr>
  );

  return (
    <div className="mt-4 space-y-6">
      <div className="grid gap-4 sm:grid-cols-4">
        {[
          ["UNUSED", unused.length, "text-fap-green"],
          ["USED", used.length, "text-fap-amber"],
          ["TRANSFERRED", transferred.length, "text-cyan"],
          ["TOTAL", (codes ?? []).length, "text-white"],
        ].map(([label, value, color]) => (
          <div key={label as string} className="rounded-2xl border border-line bg-panel/80 p-5">
            <div className="text-xs font-bold tracking-widest text-silver">{label}</div>
            <div className={`mt-1 font-mono text-4xl font-extrabold ${color}`}>
              {codes ? value : "…"}
            </div>
          </div>
        ))}
      </div>
      <ul className="list-disc space-y-1 pl-5 text-sm text-silver">
        <li>There are always exactly 10 unused codes. When one is used, a new one is created right away.</li>
        <li>A code works on one device at a time. A used code cannot be given to someone else.</li>
        <li>
          Moving to a new tablet: the student opens ⚙ SETTINGS &gt; Deactivate &amp; Transfer,
          then enters the same code on the new tablet. If the old tablet is broken, press
          Release on the code below.
        </li>
        <li>
          Codes are case-sensitive (capital letters, small letters and numbers), so give them
          exactly as shown. Activation needs an internet connection.
        </li>
      </ul>

      {message && (
        <p
          className={`rounded-lg border px-4 py-3 text-sm font-bold ${
            message.ok
              ? "border-fap-green/50 text-fap-green"
              : "border-fap-red/50 text-fap-red"
          }`}
        >
          {message.text}
        </p>
      )}

      <section className="rounded-2xl border border-fap-green/40 bg-panel/80 p-5">
        <h2 className="text-lg font-extrabold">
          Unused codes <span className="text-fap-green">({codes ? unused.length : "…"})</span>
        </h2>
        <p className="mt-1 text-sm text-silver">Ready to give to students.</p>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[480px] text-left text-sm">
            <thead className="text-xs tracking-wider text-silver">
              <tr>
                <th className="py-2">#</th>
                <th>CODE</th>
                <th>CREATED</th>
                <th className="text-right">ACTIONS</th>
              </tr>
            </thead>
            <tbody>
              {codes === null && emptyRow("Loading…")}
              {codes !== null && unused.length === 0 && emptyRow("No unused codes.")}
              {unused.map((c, i) => (
                <tr key={c.id} className="border-t border-line">
                  <td className="py-3 font-mono text-xs text-silver">{i + 1}</td>
                  <td className="font-mono text-base font-bold tracking-wide">{c.code}</td>
                  <td className="text-silver">{fmt(c.created_at)}</td>
                  <td className="space-x-2 text-right whitespace-nowrap">
                    {copyBtn(c.code)}
                    <button
                      disabled={busy}
                      onClick={() => {
                        if (!confirm(`Replace ${c.code}? It will stop working and a new code will be created.`))
                          return;
                        act(
                          () => rpc("a320_admin_delete_code", { p_token: token, p_id: c.id }),
                          `${c.code} was replaced with a new code.`,
                        );
                      }}
                      className="rounded-md border border-fap-red/50 px-2 py-1 text-xs font-bold text-fap-red disabled:opacity-50"
                    >
                      Replace
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-3 text-xs text-silver">Use Replace only if an unused code was shared by mistake.</p>
      </section>

      <section className="rounded-2xl border border-fap-amber/40 bg-panel/80 p-5">
        <div className="flex flex-wrap items-center gap-3">
          <h2 className="mr-auto text-lg font-extrabold">
            Used codes <span className="text-fap-amber">({codes ? used.length : "…"})</span>
          </h2>
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search code"
            className="w-44 rounded-lg border border-line bg-ink px-3 py-2 text-sm outline-none focus:border-cyan"
          />
        </div>
        <p className="mt-1 text-sm text-silver">
          Activated on their first device. Release frees a code for its owner&apos;s new device (use it when
          the old device is broken or lost); the old device locks itself the next time it is
          online.
        </p>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[560px] text-left text-sm">
            <thead className="text-xs tracking-wider text-silver">
              <tr>
                <th className="py-2">CODE</th>
                <th>USED AT</th>
                <th>DEVICE</th>
                <th className="text-right">ACTIONS</th>
              </tr>
            </thead>
            <tbody>
              {codes === null && emptyRow("Loading…")}
              {codes !== null &&
                usedShown.length === 0 &&
                emptyRow(used.length === 0 ? "No code has been used yet." : "No match.")}
              {usedShown.map((c) => (
                <tr key={c.id} className="border-t border-line">
                  <td className="py-3 font-mono text-base font-bold tracking-wide text-silver">{c.code}</td>
                  <td className="text-silver">{fmt(c.used_at)}</td>
                  <td className="font-mono text-xs text-silver" title={c.device_id ?? ""}>
                    {c.device_id ? `${c.device_id.slice(0, 8)}…` : "—"}
                  </td>
                  <td className="space-x-2 text-right whitespace-nowrap">
                    {copyBtn(c.code)}
                    {releaseBtn(c)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="rounded-2xl border border-cyan/40 bg-panel/80 p-5">
        <h2 className="text-lg font-extrabold">
          Transferred codes <span className="text-cyan">({codes ? transferred.length : "…"})</span>
        </h2>
        <p className="mt-1 text-sm text-silver">
          Codes moved to another device (Deactivate &amp; Transfer in the app, or Release here).
          A code <b className="text-cyan">waiting for new device</b> belongs to its owner: it is not
          one of the 10 unused codes, so do not give it to another student.
        </p>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[720px] text-left text-sm">
            <thead className="text-xs tracking-wider text-silver">
              <tr>
                <th className="py-2">CODE</th>
                <th>STATUS</th>
                <th>SINCE</th>
                <th>DEVICE</th>
                <th>TRANSFERS</th>
                <th className="text-right">ACTIONS</th>
              </tr>
            </thead>
            <tbody>
              {codes === null && emptyRow("Loading…", 6)}
              {codes !== null && transferred.length === 0 && emptyRow("No code has been transferred yet.", 6)}
              {transferred.map((c) => (
                <tr key={c.id} className="border-t border-line">
                  <td className="py-3 font-mono text-base font-bold tracking-wide">{c.code}</td>
                  <td>
                    <span
                      className={`rounded px-2 py-0.5 font-mono text-xs font-bold ${
                        c.is_used ? "bg-fap-green/15 text-fap-green" : "bg-cyan/15 text-cyan"
                      }`}
                    >
                      {c.is_used ? "ACTIVE ON NEW DEVICE" : "WAITING FOR NEW DEVICE"}
                    </span>
                  </td>
                  <td className="text-silver">{fmt(c.is_used ? c.used_at : (c.released_at ?? null))}</td>
                  <td className="font-mono text-xs text-silver" title={c.device_id ?? ""}>
                    {c.device_id ? `${c.device_id.slice(0, 8)}…` : "—"}
                  </td>
                  <td className="font-mono text-silver">{c.transfer_count ?? 0}</td>
                  <td className="space-x-2 text-right whitespace-nowrap">
                    {copyBtn(c.code)}
                    {c.is_used && releaseBtn(c)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <div className="max-w-xl">
        <Credentials token={token} onError={fail} onDone={(t) => setMessage({ text: t, ok: true })} />
      </div>
    </div>
  );
}

function Credentials({
  token,
  onError,
  onDone,
}: {
  token: string;
  onError: (e: unknown) => void;
  onDone: (text: string) => void;
}) {
  const [current, setCurrent] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPw, setConfirmPw] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (password !== confirmPw) {
      setError("The new passwords do not match.");
      return;
    }
    setBusy(true);
    try {
      const r = await rpc<{ ok: boolean; reason?: string }>("a320_admin_change_credentials", {
        p_token: token,
        p_current_password: current,
        p_new_username: username,
        p_new_password: password,
      });
      if (r.ok) {
        setCurrent("");
        setPassword("");
        setConfirmPw("");
        onDone("Admin username and password updated.");
      } else {
        setError(errorText[r.reason ?? "SERVER"] ?? errorText.SERVER);
      }
    } catch (err) {
      onError(err);
    } finally {
      setBusy(false);
    }
  };

  const field = (
    label: string,
    value: string,
    set: (v: string) => void,
    type = "password",
    auto = "new-password",
  ) => (
    <label className="mt-3 block text-xs font-bold tracking-wider text-silver">
      {label}
      <input
        type={type}
        value={value}
        onChange={(e) => set(e.target.value)}
        autoComplete={auto}
        required
        className="mt-1 w-full rounded-lg border border-line bg-ink px-3 py-2 text-base text-white outline-none focus:border-cyan"
      />
    </label>
  );

  return (
    <form onSubmit={submit} className="rounded-2xl border border-line bg-panel/80 p-5">
      <h2 className="text-lg font-extrabold">Change admin login</h2>
      {field("CURRENT PASSWORD", current, setCurrent, "password", "current-password")}
      {field("NEW USERNAME", username, setUsername, "text", "username")}
      {field("NEW PASSWORD (8+ CHARACTERS)", password, setPassword)}
      {field("CONFIRM NEW PASSWORD", confirmPw, setConfirmPw)}
      {error && <p className="mt-3 text-sm font-bold text-fap-red">{error}</p>}
      <button
        disabled={busy}
        className="mt-4 rounded-lg border border-cyan px-5 py-2 font-extrabold text-cyan disabled:opacity-50"
      >
        Save
      </button>
    </form>
  );
}
