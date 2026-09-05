# Network Security & Firewalls

## 📌 Network Defense Strategy

While Application Authorization (RLS) restricts what an authenticated user can do with their data, **Network Security** dictates who or what can connect to the database infrastructure in the first place. 

The platform relies on Supabase's network restrictions to act as the first line of defense, severely minimizing the external attack surface.

---

## 🛡️ Network Controls vs. RLS

Understanding the distinction is critical for a defense-in-depth architecture:

*   **Network Security (Firewalls):** Operates at the TCP/IP layer. It simply asks: *"Is the computer making this connection located at an approved IP address?"* It knows nothing about users, roles, or data.
*   **Application Authorization (RLS):** Operates at the data layer. It assumes the network connection is established and asks: *"Is User A allowed to read Row 12 in Table X?"*

**Crucially, a firewall does not replace RLS.** If a firewall is breached (e.g., an attacker compromises an allowed office server), RLS ensures the attacker still cannot access private customer data without valid JWT credentials.

---

## 🚦 Network Restrictions Configuration

Supabase is configured to aggressively restrict direct connection to the PostgreSQL database port (5432 / 6543) via IP allowlisting.

### Allowed Connections (Safelisted)
*   **Approved Office / VPN IPs:** Static IP ranges for authorized database administrators and internal tooling.
*   **Serverless Backends (If applicable):** Specific IP ranges for trusted external services that require direct database access (e.g., a heavily authenticated BI/reporting tool).
*   **Supabase Internal Infrastructure:** The Supabase API Gateway (PostgREST), GoTrue, and Storage systems natively communicate with the database via internal, secure VPC peering.

### Blocked Connections (Dropped)
*   **Unknown Public IPs:** Any attempt to connect directly to the database via standard PostgreSQL clients (pgAdmin, DataGrip, psql) from an unapproved public IP is summarily dropped at the network edge.
*   **Unauthorized Networks:** Traffic originating from known malicious subnets or unverified cloud provider regions.

---

## 🛑 What Network Restrictions Protect (and Don't Protect)

**What they PROTECT against:**
*   Brute-force password guessing attacks against the `postgres` user.
*   Zero-day exploits targeting the PostgreSQL database daemon itself.
*   Unauthorized exfiltration attempts by rogue developers outside of approved networks.

**What they DO NOT protect against:**
*   **API Abuse:** If the Supabase API Gateway (`https://[PROJECT_ID].supabase.co/rest/v1/...`) is public, network restrictions on port 5432 do nothing to stop a malicious actor from hitting the API. This must be handled by RLS and rate limiting.
*   **Compromised Credentials:** If a valid JWT is stolen, the attacker can use the public API gateway to access data, regardless of the database firewall.

---

## ⏱️ Rate Limiting & Abuse Protection

To protect the public-facing API gateway from volumetric attacks and abuse, the platform implements controls across multiple layers:

### 1. Network Layer (Supabase / Cloudflare)
*   *Mechanism:* WAF (Web Application Firewall) rules and global rate limiting.
*   *Protects Against:* DDoS attacks, mass port scanning, and volumetric floods targeting the Supabase project domain.

### 2. API Layer (PostgREST)
*   *Mechanism:* Connection pooling and API request quotas.
*   *Protects Against:* Excessive API requests from a single client attempting to scrape the product catalog or exhaust database connection limits.

### 3. Application Layer (Supabase Auth / GoTrue)
*   *Mechanism:* Captcha, email verification, and login attempt throttling.
*   *Protects Against:* Credential stuffing, login brute-forcing, and automated bot account creation (Signup abuse).

### 4. Database Layer (Custom Logic & Triggers)
*   *Mechanism:* Transactional constraints, RPC logic, and rate-limiting tables.
*   *Protects Against:* 
    *   **Repeated Order Creation:** `create_order()` RPC can validate the time since the last order to prevent spam.
    *   **Coupon Abuse:** Coupon tracking tables (`usage_count`, `usage_limit`) strictly enforced via atomic updates to prevent double-spending.
    *   **Review Spam:** Database constraints ensuring `UNIQUE(user_id, product_id)` to prevent multiple reviews from the same user.
