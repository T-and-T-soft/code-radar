# Code Radar Licensing

Code Radar licensing is enforced by a signed entitlement model:

1. A customer buys or redeems a license.
2. Supabase Edge Functions create a license and store only hashed secrets.
3. `radar activate <license-key>` claims a machine slot.
4. The backend returns a signed entitlement.
5. Paid commands validate the activation online and verify the signed
   entitlement with an embedded or environment-provided public key.

The private signing key never ships in the binary.

## Runtime Environment

Production release builds must be configured with:

| Variable | Location | Purpose |
| --- | --- | --- |
| `RADAR_LICENSE_API_URL` | build env or runtime env | Base URL for Supabase Edge Functions |
| `RADAR_LICENSE_PUBLIC_KEY` | build env or runtime env | Base64 Ed25519 public key used by the binary |
| `RADAR_LICENSE_KEY` | CI runtime only | License key for non-interactive activation |
| `RADAR_LICENSE_CACHE_DIR` | optional runtime env | Override local entitlement cache path |

Supabase Edge Functions require:

| Secret | Purpose |
| --- | --- |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-only DB access for Edge Functions |
| `RADAR_LICENSE_HASH_SECRET` | HMAC secret for license keys, tokens, and recovery codes |
| `RADAR_ENTITLEMENT_PRIVATE_KEY` | Base64 raw 32-byte Ed25519 private seed |
| `RADAR_ENTITLEMENT_KEY_ID` | Public key identifier included in entitlements |
| `PADDLE_WEBHOOK_SECRET` | Paddle notification destination signing secret |
| `PADDLE_API_KEY` | Server-side Paddle API key used to fetch customer email when webhook payload omits it |
| `PADDLE_API_BASE_URL` | Optional Paddle API base URL override, for example sandbox |
| `RESEND_API_KEY` | Optional transactional email provider |
| `RADAR_LICENSE_EMAIL_FROM` | Optional sender address for license emails |

## Supabase Setup

Generate the entitlement signing keys:

```bash
cargo run -p radar-license --bin generate_license_keys
```

Store `RADAR_ENTITLEMENT_PRIVATE_KEY` and `RADAR_ENTITLEMENT_KEY_ID` as
Supabase Edge Function secrets. Build release binaries with the matching
`RADAR_LICENSE_PUBLIC_KEY`.

Apply the licensing migration:

```bash
supabase db push
supabase functions deploy activate-license
supabase functions deploy validate-license
supabase functions deploy deactivate-slot
supabase functions deploy license-status
supabase functions deploy paddle-webhook
supabase functions deploy redeem-license
supabase functions deploy request-license-recovery
supabase functions deploy rotate-license-key
```

The migration creates a private `licensing` schema, enables RLS on all tables,
revokes access from `anon` and `authenticated`, and exposes only `security definer`
RPC functions for Edge Functions.

If your Supabase Data API schema allowlist excludes `licensing`, add it for the
service-role Edge Function client only. Do not grant `anon` or `authenticated`
access to licensing tables.

## Plan Catalog

Plan limits and features live in `licensing.plans`; Edge Functions read this
table when creating new licenses. Existing licenses keep a snapshot of the
limits/features they were sold with, so changing a plan affects future
purchases and redemptions only.

Initial annual plans:

| Plan | Price | Machines | Repos | GitHub Actions | Use case |
| --- | ---: | ---: | ---: | --- | --- |
| `tier_1` Solo Local | `$79/year` | 1 | 0 | No | solo local |
| `tier_2` Serious Solo | `$179/year` | 2 | 10 | Yes | serious solo dev |
| `tier_3` Freelancer | `$299/year` | 3 | 25 | Yes | freelancer/indie hacker |

To change future limits or feature access:

```sql
update licensing.plans
set machine_limit = 2,
    repo_limit = 5,
    features = array['cli_scan', 'mcp', 'agent_prompt']
where code = 'tier_1';
```

Do not edit `licensing.licenses.machine_limit`, `repo_limit`, or `features`
unless you intentionally want to change already-sold licenses.

## Paddle Checkout

Use Paddle Billing for direct purchases. Paddle is the Merchant of Record; Code
Radar only receives verified webhooks and creates local license keys.

Direct website purchases use separate `web_*` plans so public subscription
pricing is not mixed with AppSumo/StackSocial annual deal tiers.

| Plan code | Price | Machines | Repos | GitHub Actions |
| --- | ---: | ---: | ---: | --- |
| `web_solo_monthly` | `$19/month` | 1 | 0 | No |
| `web_solo_yearly` | `$179/year` | 1 | 0 | No |
| `web_pro_monthly` | `$39/month` | 2 | 10 | Yes |
| `web_pro_yearly` | `$349/year` | 2 | 10 | Yes |
| `web_studio_monthly` | `$79/month` | 3 | 25 | Yes |
| `web_studio_yearly` | `$699/year` | 3 | 25 | Yes |

Create Paddle Prices and do one of:

- pass checkout `custom_data.radar_plan=<plan_code>`;
- store the Paddle Price ID in `licensing.plans.paddle_price_id`; or
- store the Paddle Product ID in `licensing.plans.paddle_product_id` only when
  one product maps to exactly one plan.

The most explicit setup is to pass custom data when opening checkout:

```txt
custom_data = {
  "radar_plan": "web_pro_monthly"
}
```

The webhook refuses `transaction.completed` events without a matching active
plan.

Point the webhook endpoint to:

```txt
https://<project-ref>.supabase.co/functions/v1/paddle-webhook
```

Subscribe at minimum to:

- `transaction.completed`
- `transaction.payment_failed`
- `transaction.canceled`
- `subscription.activated`
- `subscription.updated`
- `subscription.canceled`
- `subscription.past_due`
- `subscription.paused`
- `subscription.resumed`
- `adjustment.created`
- `adjustment.updated`

The webhook creates:

- customer row
- license row
- purchase row
- audit event
- license email when `RESEND_API_KEY` is configured

Webhook signature verification uses `Paddle-Signature` with
`PADDLE_WEBHOOK_SECRET` and a replay timestamp tolerance. The raw request body
must be used for signature verification.

## AppSumo Licensing

Use AppSumo Licensing API v2 for AppSumo deals. AppSumo generates and manages
the marketplace `license_key`; Code Radar stores only hashed provider keys and
uses the AppSumo `tier` to select limits from `licensing.plans.appsumo_tier`.

Configure these URLs in the AppSumo Partner Portal:

```txt
OAuth Redirect URL:
https://zfwbcqpplompjuonilef.supabase.co/functions/v1/appsumo-oauth-callback

Webhook URL:
https://zfwbcqpplompjuonilef.supabase.co/functions/v1/appsumo-webhook
```

Required Supabase Edge Function secrets:

```txt
APPSUMO_LICENSING_API_KEY
APPSUMO_CLIENT_ID
APPSUMO_CLIENT_SECRET
APPSUMO_OAUTH_REDIRECT_URL
```

Webhook handling:

- `purchase` creates or updates a suspended placeholder license.
- `activate` creates or updates an active license.
- `upgrade` and `downgrade` replace the provider license key and update plan
  limits while preserving local activation slots.
- `deactivate` revokes the license and active slots.
- add-on events with `parent_license_key` are audited and ignored until add-ons
  are configured.

Customer CLI activation uses the AppSumo license key directly:

```bash
radar activate 3794577c-3dbc-11ec-9bbc-0242ac130002
```

## StackSocial And Manual Redemption

Preload hashed redemption codes into `licensing.redemption_codes` with:

```txt
source=stacksocial | manual
plan_code=tier_1 | tier_2 | tier_3
status=unused
```

The public redemption page should call:

```txt
POST /functions/v1/redeem-license
{ "code": "...", "email": "buyer@example.com" }
```

The function creates the customer, license, purchase, audit event, marks the
code as redeemed, and emails the generated license key. Raw redemption codes
are never stored.

## CLI Usage

Interactive activation:

```bash
radar activate RADAR-XXXXXX-XXXXXX-XXXXXX-XXXXXX
radar license status
radar scan .
```

Refresh the server-backed entitlement:

```bash
radar license refresh .
```

Deactivate slots:

```bash
radar license deactivate-repo .
radar license deactivate-machine .
```

Remove local cache only:

```bash
radar license logout
```

Local activation tokens are written to the private license cache file with
`0600` permissions. On first activation, Code Radar also attempts a best-effort
write to the OS credential store when available, but paid command execution does
not read from or repeatedly write to the OS credential store. The file-backed
token is required for headless child processes such as MCP clients, where OS
credential APIs can block or be unavailable.

## GitHub Actions

Store the license key as `RADAR_LICENSE_KEY` in repository secrets:

```yaml
- uses: T-and-T-soft/code-radar/action@v0
  with:
    license-key: ${{ secrets.RADAR_LICENSE_KEY }}
```

The first CI run claims a repository slot. GitHub Actions always validates
online and fails closed when validation is unavailable.

## MCP

`radar mcp` uses the same local activation token as the CLI. Activate once:

```bash
radar activate RADAR-XXXXXX-XXXXXX-XXXXXX-XXXXXX
radar mcp install all
```

MCP scan and repair tools require the `mcp` entitlement feature. The quality
gate tool requires `quality_gate`.

## Recovery And Rotation

License keys are activation secrets, not user passwords. Email is the owner
identity and is used for recovery.

Recovery flow:

1. Call `request-license-recovery` with the purchase email and `purpose=rotate_key`.
2. The customer receives a one-time recovery code.
3. Call `rotate-license-key` with email and recovery code.
4. The old license key is replaced and all active slots are revoked.

This prevents someone with a leaked license key from deactivating another
customer's machines or rotating the key without email proof.

## Release Checklist

- Build release binary with `RADAR_LICENSE_API_URL` and `RADAR_LICENSE_PUBLIC_KEY`.
- Keep `RADAR_ENTITLEMENT_PRIVATE_KEY` only in Supabase secrets.
- Confirm Paddle webhook signature verification with a simulator event.
- Confirm Paddle refunds set license status to `refunded`.
- Confirm machine and repository limits reject extra slots.
- Confirm `radar scan`, `radar prompt`, `radar verify`, and MCP tools fail with a clear license error when unlicensed.
- Confirm paid commands fail when the license server rejects or cannot validate the activation.
- Run smoke tests on macOS, Linux, and Windows.
