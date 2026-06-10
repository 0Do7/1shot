# Deferred: Cloud Sharing (hosted instant links)

**Status:** locked v2 deferral (decided 2026-06-09). Local-first is the MVP wedge — the angriest
CleanShot VOC anywhere is the forced cloud ("Forcing your own cloud should be illegal").
But business users simultaneously call link-sharing "crucial" (~38 mentions each way, §1.9).
Both constituencies are real; serve the local-first one first.

## The spec bar when revived (report §3.6, §6)
- **"Link is copied to clipboard before upload even finishes"** — the loved CleanShot behavior.
- Transparent retention (never replicate CleanShot's 24h silent video self-destruct trust wound).
- Optional/invisible until enabled — never upsold inside the capture flow.
- Pricing: subscription is legitimate here (real recurring cost), ~$4–6/mo, far under the
  $96–120/yr rage line.
- Corporate-trust posture: clear data policy (Shottr was banned at a company over its
  public-uploads model).

## MVP stopgap kept in scope
S3 / self-hosted / custom-endpoint upload (Shottr v1.9 proved this defuses power-user demand)
— user's own bucket, zero cost to us.

## Architectural hook
Destination plugin surface; hosted cloud is one more destination + auth.

## Revisit trigger
v2, alongside or after video recording; signaled by business-user requests and support-tool jobs.
