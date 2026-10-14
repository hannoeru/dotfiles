---
name: nuxt-cloudflare
description: "Set up, type, and deploy Nuxt/Nitro apps on Cloudflare Workers (D1, R2, KV, Queues, Email). Use for the `cloudflare_module` / `cloudflare_pages` preset, accessing bindings via `event.context.cloudflare.env` (Nitro 2) vs `event.req.runtime.cloudflare.env` (Nitro 3), `wrangler types` binding typegen, and the `server/env.d.ts` + `H3EventContext` augmentation that makes `event.context.cloudflare.env` typed in Nuxt's split tsconfig."
license: MIT
---

# Nuxt on Cloudflare

The `cloudflare_module` preset injects every Wrangler binding into the request event as `event.context.cloudflare = { request, env, context }`. `env` holds the bindings (`DB`, `LISTING_IMAGES`, `EMAIL`, …), `context` is the Cloudflare `ExecutionContext`. Dev and prod both populate it; only the access path name changes across Nitro major versions.

## Configure

1. Set the preset and declare bindings.

   ```ts
   // nuxt.config.ts
   export default defineNuxtConfig({ nitro: { preset: 'cloudflare_module' } })
   ```

   ```jsonc
   // wrangler.jsonc
   {
     "main": ".output/server/index.mjs",
     "compatibility_date": "…",
     "compatibility_flags": ["nodejs_compat"],
     "d1_databases": [{ "binding": "DB", "database_name": "…", "database_id": "…", "migrations_dir": "migrations" }],
     "r2_buckets": [{ "binding": "LISTING_IMAGES", "bucket_name": "…" }],
     "send_email": [{ "name": "EMAIL" }]
   }
   ```

   **Done when** `pnpm dev` boots and `wrangler.jsonc` lists every binding the routes touch.

2. Keep bindings inside the request lifecycle. They exist only per-request (Cloudflare injects them at fetch time), so never read a binding at module top level — read it from `event` inside a handler or helper.

## Access bindings

Pick the access path for the installed Nitro major, then confirm it in `node_modules` rather than trusting memory:

| Nitro | Access path |
| --- | --- |
| Nitro 2 (`nitropack@2.x`, what Nuxt 4 ships) | `event.context.cloudflare.env` |
| Nitro 3 (nightly) | `event.req.runtime.cloudflare.env` |

**Done when** `console.log(event.context.cloudflare)` shows `{ request, env, context }` in `nuxt dev` and in the deployed Worker.

Wrap each binding in a typed helper co-located with the route layer, so handlers never touch the cast:

```ts
// server/database/client.ts — D1 via Drizzle
import { drizzle } from 'drizzle-orm/d1'

export function useDatabase(event: H3Event) {
  const cloudflare = event.context.cloudflare
  if (!cloudflare) throw createError({ statusCode: 500, statusMessage: 'Cloudflare bindings are unavailable.' })
  return drizzle(cloudflare.env.DB, { schema })
}
```

```ts
// server/utils/storage.ts — R2
export function useImagesBucket(event: H3Event): R2Bucket {
  const bucket = event.context.cloudflare?.env.LISTING_IMAGES
  if (!bucket) throw createError({ statusCode: 500, statusMessage: '圖片儲存服務不可用。' })
  return bucket
}
```

## Type the bindings

Nuxt's generated server tsconfig only includes `server/**/*`, so a root `.d.ts` is invisible to it. Wire the generated types in explicitly.

1. Generate from the Wrangler config:

   ```bash
   pnpm exec wrangler types --env-interface CloudflareEnv
   ```

   This writes `worker-configuration.d.ts` with `interface CloudflareEnv { DB: D1Database; LISTING_IMAGES: R2Bucket; EMAIL: SendEmail; … }`. Keep `--include-runtime` on (the default): it emits a self-contained file that also declares `R2Bucket`/`D1Database`/`SendEmail`/`ExecutionContext` from workerd, so you can drop `@cloudflare/workers-types`.

2. Add `server/env.d.ts` — reference the generated file and augment h3's event context:

   ```ts
   /// <reference path="../worker-configuration.d.ts" />

   declare module 'h3' {
     interface H3EventContext {
       cloudflare?: {
         request: Request
         env: CloudflareEnv
         context: ExecutionContext
       }
     }
   }

   export {}
   ```

3. **Make the file a module.** The trailing `export {}` is required. Without it `server/env.d.ts` is a global script, and its `declare module 'h3'` *shadows* the real `h3` instead of merging — `getQuery`, `getRouterParam`, and `event.context` all stop resolving. `export {}` turns the declaration into an augmentation.

4. Commit `worker-configuration.d.ts` and add a regenerate script:

   ```jsonc
   { "scripts": { "cf-typegen": "wrangler types --env-interface CloudflareEnv" } }
   ```

   **Done when** `pnpm typecheck` passes with `event.context.cloudflare.env.DB` resolving as `D1Database` (no `any`, no `as` casts in the helpers).

## Develop and deploy

- `nuxt dev` reads `wrangler.jsonc` through Miniflare's `getPlatformProxy()`, so local bindings work with no proxy step; state persists in `.wrangler/state/v3`. Secrets go in `.dev.vars` (gitignored).
- To test the production build: `pnpm build` then `npx wrangler dev .output/server/index.mjs --assets .output/public` (or `wrangler dev --env preview --local`).
- Apply D1 migrations explicitly — `wrangler deploy` does not run them: `pnpm exec wrangler d1 migrations apply <db> --remote --env <env>`.
- In CI, fail on type drift: run `wrangler types --check` before `pnpm typecheck`; regenerate after any `wrangler.jsonc` change.

## Reference

- `wrangler types` flags: `--env-interface <name>` (default `Env`), `--include-runtime` (default true, self-contained), `--include-env`, `--strict-vars`, `--check`.
- `--include-runtime=false` leaves a tiny file but its `R2Bucket`/`D1Database`/`SendEmail` names must then resolve from `@cloudflare/workers-types`, which is awkward to feed through Nuxt's split tsconfig — prefer the default rather than hand-wiring `@cloudflare/workers-types` as an ambient global.
- Bindings are available only during the request lifecycle — never at module init.