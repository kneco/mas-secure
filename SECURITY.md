# Security Policy — ai-enclave

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  Host (Windows / WSL2)                                  │
│                                                         │
│  ┌─────────────────────────┐   ┌────────────────────┐  │
│  │  Docker Container       │   │  Secret Daemon     │  │
│  │  (ai-enclave)           │   │  (Host Process)    │  │
│  │                         │   │  No LLM            │  │
│  │  Claude Code + LLM ──── │──▶│  Unix Socket       │  │
│  │  /workspace (rw)        │   │  API key vault     │  │
│  │                         │   └────────────────────┘  │
│  └────────────┬────────────┘                            │
│               │ read-only                               │
│  /intel ──────┘  (bind mount :ro)                       │
│  (knowledge/config)                                     │
└─────────────────────────────────────────────────────────┘
```

**Data flow policy:**

- intel → container: one-way (read-only)
- container → Secret Daemon: Unix socket (API key usage only; no LLM exists on the Daemon side)
- container → internet: unrestricted (not yet implemented; see Section 2)

---

## Section 1: Container Isolation — Protecting Your Machine

### 1.1 Filesystem Isolation

| Mount | Type | Access | Purpose |
|-------|------|--------|---------|
| `/workspace` | named volume | read-write | LLM working area, isolated from host filesystem |
| `/intel` | bind mount | **read-only** | Knowledge and configuration provided to the container |

**Named volume vs. bind mount:** A named volume is managed by Docker and does not expose a direct path on the host filesystem to the container. A bind mount maps a host directory into the container; the `:ro` flag prevents writes.

### 1.2 The intel Mechanism

The `/intel` directory is kept separate from `/workspace` to avoid mixing the area where the LLM writes code (`/workspace`) with the area that supplies configuration and knowledge (`/intel`). The read-only enforcement ensures that the LLM inside the container cannot tamper with intel contents.

### 1.3 Process Isolation

- Claude Code runs as a non-root user (`agent`, uid=1000), following the principle of least privilege.
- `no-new-privileges` is **not yet configured** in `docker-compose.yml`; adding it is recommended.

---

## Section 2: Credential Protection — Keeping Secrets Inside the Container

### 2.1 Threat Structure

In an environment where an LLM agent executes autonomously, the entity that *uses* credentials and the entity that can *leak* them exist within the same process. This is a distinct risk profile compared to server-side leakage in a conventional web application.

### 2.2 Attack Surface by Storage Method

| Storage method | Visible to LLM? | Ease of theft | Recommendation |
|----------------|-----------------|---------------|----------------|
| Environment variable | ✅ Yes | High (`/proc/self/environ`) | ❌ Anti-pattern |
| File (plaintext) | ✅ Yes | High | ❌ |
| File (encrypted) | △ Ciphertext only | Medium | △ |
| Secret Daemon | ❌ No | Low (SO_PEERCRED auth) | ✅ Recommended |
| Docker secrets | △ File at runtime | Medium | △ |

### 2.3 Why Environment Variables Are an Anti-Pattern

- `process.env` / `os.environ` allows direct read-back from LLM tools.
- `/proc/self/environ` exposes all environment variables to any process in the container.
- A prompt injection attack can instruct the LLM to exfiltrate API keys to an external endpoint.

### 2.4 Secret Daemon (implemented)

**Core design principle: "The side that holds secrets must not contain an LLM."**

- The Secret Daemon runs as a host process (outside the container).
- The LLM can only *use* API keys through the Unix socket — it cannot retrieve the raw key value.
- SO_PEERCRED authentication rejects connections from any process not on the whitelist.
- The `get_key` command has been removed since v2.0.0; direct key retrieval by the LLM is no longer possible by design.

### 2.5 apiKeyHelper + Secret Daemon Integration (not implemented)

Integration of Claude Code's API key helper feature with the Secret Daemon is not yet implemented. Whether OAuth token handling is supported has not been verified (see Unresolved Issue #1).

### 2.6 Permission Deny Rules (not implemented)

Restricting file access and command execution through Claude Code configuration is not yet implemented. Comprehensive coverage of bypass patterns remains an open problem (see Unresolved Issue #2).

### 2.7 Network Controls (not implemented)

Outbound traffic restrictions from the container are not yet implemented (see Unresolved Issue #3).

---

## Section 3: LLM-Specific Threats

### 3.1 Prompt Injection

**Attack scenario:** The LLM reads malicious content (a web page, a file, etc.) and, following embedded attacker instructions, exfiltrates credentials to an external server.

**Known CVEs:**

- **CVE-2025-59536** — Prompt injection vulnerability in Claude Code
- **CVE-2026-21852** — Tool-call-path injection in LLM agent frameworks

**Mitigation:** Secret Daemon isolates credentials so the LLM never knows the key value, limiting the impact of a successful injection.

### 3.2 Credentials in Claude Code's Internal Memory

Authentication information may temporarily exist within Claude Code's context window during a session. This is a risk accepted by design — complete elimination is not feasible. The operational mitigation is to avoid inputting credential values into the context.

---

## Section 4: Design Decision Record

| Decision | Choice | Rejected alternatives | Rationale |
|----------|---------|-----------------------|-----------|
| Credential management | Secret Daemon (host process) | Environment variables, encrypted files | Complete separation of LLM and key storage |
| Container user | Non-root (uid=1000) | root | Principle of least privilege |
| intel placement | Read-only bind mount | Co-located in /workspace | Prevent LLM from tampering with configuration |
| Workspace storage | Named volume | Read-write bind mount | Block direct access to host filesystem |
| code-server authentication | `--auth none` | Password auth | Local environment assumed; usability prioritized |

---

## Section 5: Unresolved Issues

The following six items are currently unresolved, not yet implemented, or not yet verified.

| # | Issue | Status |
|---|-------|--------|
| 1 | Whether apiKeyHelper supports OAuth tokens | Unverified |
| 2 | Comprehensive coverage of Permission Deny Rules bypass patterns | Not implemented |
| 3 | Docker network controls (outbound traffic restriction) | Not implemented |
| 4 | Behavior of Claude Code sandbox feature inside the container | Unverified |
| 5 | Long-term token operation flow for setup-token | Not designed |
| 6 | Cross-container Secret Daemon communication — whether Unix socket + SO_PEERCRED can operate across the container boundary | Unresolved |
