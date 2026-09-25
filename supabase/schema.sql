-- ============================================================================
-- LEGACY SUPABASE SCHEMA — NOT THE CURRENT BACKEND CONTRACT
-- ============================================================================
-- The official v1 backend is the Spring/PostgreSQL event API documented in:
-- FLUTTER_SERVER_CONNECTION_AR.md, API_CONTRACT_AR.md, EVENT_CATALOG_AR.md and
-- openapi.yaml. Do not apply this legacy Supabase projection schema to that
-- server and do not use it to implement Flutter synchronization.
-- This file is retained only as historical/local-schema reference.
-- ============================================================================
--
-- PURPOSE
-- -------
-- This legacy file previously targeted a fresh Supabase/PostgreSQL project and
-- documents:
--   1. the business modules and tables;
--   2. data conventions and document lifecycle;
--   3. authentication / tenant isolation rules;
--   4. the mobile/desktop offline sync contract;
--   5. the remaining backend integration work.
--
-- Client stack: Flutter + Riverpod + SQLite (offline-first).
-- Local database version: 6.
-- Server target: Supabase/PostgreSQL.
-- Local schema source: lib/core/db/schema/*.dart
-- Client sync source: lib/core/sync/sync_engine.dart
--
-- HISTORICAL APPLY NOTES (DO NOT APPLY TO THE CURRENT SPRING SERVER)
-- ------------
-- 1. Create a new Supabase project.
-- 2. Open SQL Editor as the project owner/service role.
-- 3. Execute this entire file once from top to bottom.
-- 4. Create an auth.users account, then create its public.users mapping.
-- 5. Do not expose the service-role key to the Flutter client.
-- 6. Implement the push transport described below; pull is already provided
--    by get_sync_changes() and get_last_server_seq().
--
-- The script uses CREATE TABLE IF NOT EXISTS, CREATE OR REPLACE FUNCTION and
-- explicit DROP/CREATE for triggers and policies, so it is safe to rerun for
-- the objects defined here. It is not a destructive reset script.
--
-- ----------------------------------------------------------------------------
-- SYSTEM MODULES AND SERVER TABLES (36)
-- ----------------------------------------------------------------------------
--
-- CORE / TENANCY (4)
--   entities, users, devices, financial_years
--
-- CATALOG (7)
--   parties, categories, products, product_specifications, product_units,
--   barcodes, warehouses
--
-- INVENTORY (6)
--   inventory_items, inventory_movements,
--   inventory_adjustments, inventory_adjustment_items,
--   inventory_transfers, inventory_transfer_items
--
-- DOCUMENTS (10)
--   sales, sale_items,
--   purchase_invoices, purchase_items,
--   sale_return_invoices, sale_return_items,
--   purchase_return_invoices, purchase_return_items,
--   waste_invoices, waste_items
--
-- CASH / PARTY ACCOUNTING (7)
--   cashboxes, cash_sessions, transactions, party_ledger_entries,
--   expenses, cash_transfers, cash_adjustments
--
-- SERVER SYNC INFRASTRUCTURE (2)
--   sync_operation_receipts, sync_log
--
-- CLIENT-ONLY SQLITE TABLES — DO NOT CREATE ON THE SERVER
--   app_context            selected local workspace/year/defaults
--   keyboard_shortcuts     local UI preferences
--   sync_operations        local record of accepted pushes
--   sync_outbox            pending client operations
--   sync_changes           locally applied server changes
--   sync_conflicts         conflicts awaiting local resolution
--
-- ----------------------------------------------------------------------------
-- DATA CONVENTIONS
-- ----------------------------------------------------------------------------
--
-- IDs
--   PostgreSQL: uuid.
--   Flutter creates IDs using uuid.v4() before offline inserts.
--   The server MUST preserve client-generated IDs for idempotency.
--
-- MONEY
--   All monetary values use bigint minor units; never float/decimal.
--   Example: 15.00 is stored as 1500 when the currency has two decimals.
--   Relevant columns end with _minor.
--
-- QUANTITIES
--   Stored as double precision. A selected unit is converted to base units by:
--     base_quantity = quantity * unit_factor_at_<operation>
--   Historical unit factors are copied into document items and never inferred
--   later from the current product_units row.
--
-- TIME
--   Timestamps and business dates are ISO-8601 UTC text, intentionally matching
--   Dart DateTime.toIso8601String(). Do not silently convert payload fields to
--   locale-formatted dates.
--
-- MULTI-TENANCY
--   entity_id is the tenant boundary. Every request must be authenticated and
--   every inserted/updated entity-scoped row must match auth_entity_id().
--   Never accept entity_id only because it is present in a client payload.
--
-- SOFT DELETE
--   Mutable master data uses deleted_at. Hard DELETE is not part of the public
--   API. Immutable ledger rows reject UPDATE and DELETE at trigger level.
--
-- VERSIONING
--   Mutable/versioned rows start at version = 1. Server triggers increment the
--   version on UPDATE. The resulting row is recorded in sync_log.
--
-- ----------------------------------------------------------------------------
-- ACCOUNTING INVARIANTS
-- ----------------------------------------------------------------------------
--
-- DOCUMENT STATUS
--   draft -> posted -> void
--   A posted/void document is immutable except the controlled posted -> void
--   transition. Corrections must be represented by reversal ledger rows.
--
-- APPEND-ONLY TABLES
--   inventory_movements, transactions, party_ledger_entries,
--   sale_items, purchase_items, sale_return_items, purchase_return_items,
--   waste_items, inventory_adjustment_items, inventory_transfer_items.
--   These tables reject UPDATE/DELETE on the server.
--
-- CACHE FIELDS
--   inventory_items.current_quantity
--   inventory_items.inventory_value_minor
--   cashboxes.current_balance_minor
--   parties.current_balance_minor
--   These are cached balances. Their source of truth is respectively:
--   inventory_movements, transactions, and party_ledger_entries.
--   A backend should not trust client-supplied cache totals; derive/rebuild them
--   transactionally from immutable ledgers.
--
-- POSTING MUST BE ATOMIC
--   Posting/voiding any sale, purchase, return, waste, expense, transfer or
--   adjustment must run in one database transaction and either write all of:
--     header + items + inventory ledger + cash ledger + party ledger
--   or write nothing.
--
-- FINANCIAL YEAR
--   New accounting movements require an open financial_years row. Closed years
--   must reject new posting and voiding unless an explicit privileged workflow
--   is later designed.
--
-- ----------------------------------------------------------------------------
-- AUTHENTICATION AND ONBOARDING
-- ----------------------------------------------------------------------------
--
-- public.users.auth_user_id references auth.users.id.
-- auth_entity_id() resolves the tenant through that mapping.
-- Recommended onboarding order (server/service-role operation):
--   1. create auth.users account;
--   2. create entities row;
--   3. create public.users row with auth_user_id + entity_id;
--   4. create financial_years row;
--   5. create default warehouse and cashbox;
--   6. register the client device.
--
-- RLS is enabled on all public business tables. The supplied policies scope
-- rows to auth_entity_id(). Administrative onboarding must therefore run via a
-- trusted server/service-role path, not by exposing service credentials.
--
-- ----------------------------------------------------------------------------
-- OFFLINE SYNC CONTRACT REQUIRED BY THE FLUTTER CLIENT
-- ----------------------------------------------------------------------------
--
-- The Flutter app stores one operation in sync_outbox for each local mutation.
-- SyncEngine calls a SyncTransport with the following logical contract.
--
-- PUSH REQUEST
--   POST /sync/push                           (name may change)
--   Authorization: Bearer <Supabase JWT>
--   Content-Type: application/json
--
--   {
--     "operation_id": "uuid",
--     "entity_id": "uuid",
--     "aggregate_type": "sale",
--     "aggregate_id": "uuid",
--     "action": "post",
--     "payload_json": "{...}",
--     "created_at": "ISO-8601 UTC"
--   }
--
-- PUSH RESPONSE
--   {
--     "operationId": "uuid",
--     "accepted": true,
--     "error": null
--   }
--
-- PUSH REQUIREMENTS
--   * Authenticate the JWT and derive entity/user on the server.
--   * Reject operation.entity_id when it differs from auth_entity_id().
--   * Treat operation_id as an idempotency key. Retrying the same operation
--     must return the original result without applying accounting entries twice.
--   * Decode payload_json as an object and validate IDs, status and ownership.
--   * Apply the aggregate in a single transaction.
--   * Return accepted=false plus a stable error message for business rejection.
--   * Do not accept arbitrary table names or arbitrary SQL from the client.
--
-- IDEMPOTENCY FLOW USING sync_operation_receipts
--   1. Insert operation_id with status='processing' using ON CONFLICT DO NOTHING.
--   2. If the insert conflicts, load and return the stored result; do not replay.
--   3. Apply the validated aggregate in the same controlled backend workflow.
--   4. Store accepted/rejected result and response_json on the receipt.
--   5. A stale 'processing' receipt requires an explicit recovery policy; never
--      assume it is safe to execute the accounting mutation a second time.
--
-- AGGREGATE TYPES CURRENTLY EMITTED BY THE APP
--   party, category, product, product_unit, barcode, product_specification,
--   warehouse, financial_year, cashbox,
--   inventory_opening, inventory_adjustment, inventory_transfer,
--   sale, purchase, sale_return, purchase_return, waste,
--   cash_opening_balance, expense, cash_transfer, cash_adjustment,
--   party_payment, cash_session.
--
-- ACTIONS CURRENTLY EMITTED
--   create, update, delete, draft, post, void, open, close.
--
-- IMPORTANT PUSH GAP
--   This SQL file supplies tables, constraints, RLS, triggers and the pull feed.
--   It intentionally does not expose a generic dynamic-SQL push RPC. The backend
--   developer must implement a validated Edge Function/API dispatcher for the
--   aggregate/action pairs above, plus persistent operation-id deduplication.
--   The Flutter default transport is currently DisabledSyncTransport until that
--   endpoint is connected.
--
-- PULL REQUEST
--   The backend can call the supplied RPC directly:
--     select * from get_sync_changes(<entity_uuid>, <last_server_seq>);
--
-- PULL RESPONSE ITEM
--   {
--     "server_seq": 123,
--     "table_name": "products",
--     "record_id": "uuid",
--     "change_type": "insert|update|delete",
--     "record_version": 2,
--     "payload_json": { ... complete row ... },
--     "changed_at": "ISO-8601 UTC"
--   }
--
-- The client applies changes in server_seq order, stores its cursor in
-- devices.last_pulled_server_seq, then rebuilds cached balances from ledgers.
-- Maximum rows returned per call: 1000. Call repeatedly until caught up.
--
-- ----------------------------------------------------------------------------
-- BACKEND DELIVERY CHECKLIST
-- ----------------------------------------------------------------------------
-- [ ] Apply this schema to Supabase.
-- [ ] Configure Auth and trusted onboarding.
-- [ ] Implement idempotent /sync/push dispatcher.
-- [ ] Connect Flutter SyncTransport to push + get_sync_changes pull.
-- [ ] Add integration tests for retrying the same operation_id.
-- [ ] Test tenant isolation with two different entity users.
-- [ ] Test draft -> posted -> void and reject all other status mutations.
-- [ ] Test atomic rollback when any ledger insert fails.
-- [ ] Test conflict/version behavior and pull pagination above 1000 changes.
-- [ ] Keep the Supabase service-role key server-side only.
--
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------

create or replace function iso_now() returns text
language sql stable as $$
  select to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
$$;

-- current entity for the authenticated user (RLS bridge)
create or replace function auth_entity_id() returns uuid
language sql stable security definer set search_path = public as $$
  select entity_id
  from public.users
  where auth_user_id = auth.uid()
    and deleted_at is null
  limit 1
$$;

-- ---------------------------------------------------------------------
-- 1. core
-- ---------------------------------------------------------------------

create table if not exists entities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  currency_code text not null default 'USD',
  timezone text not null default 'UTC',
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1
);

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete cascade,
  entity_id uuid not null references entities(id) on delete cascade,
  name text not null,
  email text,
  phone text,
  is_admin boolean not null default false,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1
);

create table if not exists devices (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  user_id uuid references users(id) on delete set null,
  device_key text not null,
  name text not null,
  last_sync_at text,
  last_pulled_server_seq bigint not null default 0,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  revoked_at text,
  version integer not null default 1,
  unique (entity_id, device_key)
);

create table if not exists financial_years (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  name text not null,
  starts_on text not null,
  ends_on text not null,
  is_open boolean not null default true,
  closed_at text,
  closed_by uuid references users(id) on delete set null,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  version integer not null default 1
);

-- ---------------------------------------------------------------------
-- 2. catalog
-- ---------------------------------------------------------------------

create table if not exists parties (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  name text not null,
  phone text,
  email text,
  address text,
  tax_number text,
  type text not null default 'customer' check (type in ('customer','supplier','both')),
  opening_balance_minor bigint not null default 0,
  current_balance_minor bigint not null default 0,
  credit_limit_minor bigint,
  default_account_id uuid,
  is_active boolean not null default true,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1
);

create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  name text not null,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1,
  unique (entity_id, name)
);

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  category_id uuid references categories(id) on delete set null,
  name text not null,
  min_quantity double precision not null default 0,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1
);

create table if not exists product_specifications (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  title text not null,
  value text not null,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1
);

create table if not exists product_units (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  name text not null,
  factor double precision not null default 1 check (factor > 0),
  is_primary boolean not null default false,
  sale_price_minor bigint not null default 0 check (sale_price_minor >= 0),
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1
);

alter table product_units
  add column if not exists sale_price_minor bigint not null default 0
  check (sale_price_minor >= 0);

create table if not exists barcodes (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  product_unit_id uuid not null references product_units(id) on delete restrict,
  code text not null,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1,
  unique (entity_id, code)
);

create table if not exists warehouses (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  name text not null,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1,
  unique (entity_id, name)
);

-- ---------------------------------------------------------------------
-- 3. inventory
-- ---------------------------------------------------------------------

create table if not exists inventory_items (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  product_id uuid not null references products(id) on delete restrict,
  warehouse_id uuid not null references warehouses(id) on delete restrict,
  current_quantity double precision not null default 0,
  inventory_value_minor bigint not null default 0,
  updated_at text not null default iso_now(),
  version integer not null default 1,
  unique (entity_id, product_id, warehouse_id)
);

create table if not exists inventory_movements (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  financial_year_id uuid not null references financial_years(id) on delete restrict,
  inventory_item_id uuid not null references inventory_items(id) on delete restrict,
  movement_type text not null check (movement_type in ('opening_balance','purchase','sale','sale_return','purchase_return','waste','adjustment','transfer_in','transfer_out','reversal')),
  quantity_delta double precision not null,
  value_delta_minor bigint not null,
  reference_type text not null,
  reference_id text not null,
  reference_item_id text,
  reversal_of_id uuid references inventory_movements(id) on delete restrict,
  created_by uuid references users(id) on delete set null,
  origin_device_id uuid references devices(id) on delete set null,
  occurred_at text not null,
  created_at text not null default iso_now()
);

create table if not exists inventory_adjustments (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  financial_year_id uuid not null references financial_years(id) on delete restrict,
  warehouse_id uuid not null references warehouses(id) on delete restrict,
  adjustment_number text not null,
  status text not null default 'draft' check (status in ('draft','posted','void')),
  note text,
  created_by uuid references users(id) on delete set null,
  origin_device_id uuid references devices(id) on delete set null,
  occurred_at text not null,
  posted_at text,
  voided_at text,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1,
  unique (entity_id, adjustment_number)
);

create table if not exists inventory_adjustment_items (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  inventory_adjustment_id uuid not null references inventory_adjustments(id) on delete cascade,
  inventory_item_id uuid not null references inventory_items(id) on delete restrict,
  product_unit_id uuid not null references product_units(id) on delete restrict,
  quantity_before double precision not null,
  counted_quantity double precision not null,
  quantity_delta double precision not null,
  unit_factor_at_adjustment double precision not null check (unit_factor_at_adjustment > 0),
  value_delta_minor bigint not null default 0,
  created_at text not null default iso_now()
);

create table if not exists inventory_transfers (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  financial_year_id uuid not null references financial_years(id) on delete restrict,
  transfer_number text not null,
  from_warehouse_id uuid not null references warehouses(id) on delete restrict,
  to_warehouse_id uuid not null references warehouses(id) on delete restrict,
  status text not null default 'draft' check (status in ('draft','posted','void')),
  note text,
  created_by uuid references users(id) on delete set null,
  origin_device_id uuid references devices(id) on delete set null,
  occurred_at text not null,
  posted_at text,
  voided_at text,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1,
  check (from_warehouse_id <> to_warehouse_id),
  unique (entity_id, transfer_number)
);

create table if not exists inventory_transfer_items (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  inventory_transfer_id uuid not null references inventory_transfers(id) on delete cascade,
  product_id uuid not null references products(id) on delete restrict,
  product_unit_id uuid not null references product_units(id) on delete restrict,
  quantity double precision not null check (quantity > 0),
  unit_factor_at_transfer double precision not null check (unit_factor_at_transfer > 0),
  base_quantity double precision not null check (base_quantity > 0),
  inventory_value_minor bigint not null default 0,
  created_at text not null default iso_now()
);

-- ---------------------------------------------------------------------
-- 4. documents (sales / purchases / returns / waste)
-- ---------------------------------------------------------------------

create table if not exists sales (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  financial_year_id uuid not null references financial_years(id) on delete restrict,
  invoice_number text not null,
  created_by uuid references users(id) on delete set null,
  origin_device_id uuid references devices(id) on delete set null,
  party_id uuid references parties(id) on delete restrict,
  status text not null default 'draft' check (status in ('draft','posted','void')),
  subtotal_minor bigint not null default 0,
  discount_minor bigint not null default 0 check (discount_minor >= 0),
  final_minor bigint not null default 0,
  paid_minor bigint not null default 0 check (paid_minor >= 0),
  cashbox_id uuid,
  note text,
  occurred_at text not null,
  posted_at text,
  voided_at text,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1,
  unique (entity_id, invoice_number)
);

create table if not exists sale_items (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  sale_id uuid not null references sales(id) on delete cascade,
  inventory_item_id uuid not null references inventory_items(id) on delete restrict,
  product_unit_id uuid not null references product_units(id) on delete restrict,
  quantity double precision not null check (quantity > 0),
  unit_factor_at_sale double precision not null check (unit_factor_at_sale > 0),
  base_quantity double precision not null check (base_quantity > 0),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  line_discount_minor bigint not null default 0 check (line_discount_minor >= 0),
  line_total_minor bigint not null check (line_total_minor >= 0),
  net_amount_minor bigint not null default 0,
  cost_amount_minor bigint not null default 0,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1
);

create table if not exists purchase_invoices (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  financial_year_id uuid not null references financial_years(id) on delete restrict,
  invoice_number text not null,
  supplier_invoice_number text,
  created_by uuid references users(id) on delete set null,
  origin_device_id uuid references devices(id) on delete set null,
  party_id uuid references parties(id) on delete restrict,
  status text not null default 'draft' check (status in ('draft','posted','void')),
  subtotal_minor bigint not null default 0,
  discount_minor bigint not null default 0 check (discount_minor >= 0),
  final_minor bigint not null default 0,
  paid_minor bigint not null default 0 check (paid_minor >= 0),
  cashbox_id uuid,
  note text,
  occurred_at text not null,
  posted_at text,
  voided_at text,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1,
  unique (entity_id, invoice_number)
);

create table if not exists purchase_items (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  purchase_invoice_id uuid not null references purchase_invoices(id) on delete cascade,
  inventory_item_id uuid not null references inventory_items(id) on delete restrict,
  product_unit_id uuid not null references product_units(id) on delete restrict,
  quantity double precision not null check (quantity > 0),
  unit_factor_at_purchase double precision not null check (unit_factor_at_purchase > 0),
  base_quantity double precision not null check (base_quantity > 0),
  unit_cost_minor bigint not null check (unit_cost_minor >= 0),
  line_discount_minor bigint not null default 0 check (line_discount_minor >= 0),
  line_total_minor bigint not null check (line_total_minor >= 0),
  cost_amount_minor bigint not null default 0,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1
);

create table if not exists sale_return_invoices (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  financial_year_id uuid not null references financial_years(id) on delete restrict,
  return_number text not null,
  sale_id uuid references sales(id) on delete restrict,
  created_by uuid references users(id) on delete set null,
  origin_device_id uuid references devices(id) on delete set null,
  party_id uuid references parties(id) on delete restrict,
  status text not null default 'draft' check (status in ('draft','posted','void')),
  subtotal_minor bigint not null default 0,
  discount_minor bigint not null default 0,
  final_minor bigint not null default 0,
  refunded_minor bigint not null default 0,
  cashbox_id uuid,
  note text,
  occurred_at text not null,
  posted_at text,
  voided_at text,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1,
  unique (entity_id, return_number)
);

create table if not exists sale_return_items (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  sale_return_invoice_id uuid not null references sale_return_invoices(id) on delete cascade,
  sale_item_id uuid references sale_items(id) on delete restrict,
  inventory_item_id uuid not null references inventory_items(id) on delete restrict,
  product_unit_id uuid not null references product_units(id) on delete restrict,
  quantity double precision not null check (quantity > 0),
  unit_factor_at_return double precision not null check (unit_factor_at_return > 0),
  base_quantity double precision not null check (base_quantity > 0),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  line_total_minor bigint not null check (line_total_minor >= 0),
  cost_amount_minor bigint not null default 0,
  created_at text not null default iso_now()
);

create table if not exists purchase_return_invoices (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  financial_year_id uuid not null references financial_years(id) on delete restrict,
  return_number text not null,
  purchase_invoice_id uuid references purchase_invoices(id) on delete restrict,
  created_by uuid references users(id) on delete set null,
  origin_device_id uuid references devices(id) on delete set null,
  party_id uuid references parties(id) on delete restrict,
  status text not null default 'draft' check (status in ('draft','posted','void')),
  subtotal_minor bigint not null default 0,
  discount_minor bigint not null default 0,
  final_minor bigint not null default 0,
  refunded_minor bigint not null default 0,
  cashbox_id uuid,
  note text,
  occurred_at text not null,
  posted_at text,
  voided_at text,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1,
  unique (entity_id, return_number)
);

create table if not exists purchase_return_items (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  purchase_return_invoice_id uuid not null references purchase_return_invoices(id) on delete cascade,
  purchase_item_id uuid references purchase_items(id) on delete restrict,
  inventory_item_id uuid not null references inventory_items(id) on delete restrict,
  product_unit_id uuid not null references product_units(id) on delete restrict,
  quantity double precision not null check (quantity > 0),
  unit_factor_at_return double precision not null check (unit_factor_at_return > 0),
  base_quantity double precision not null check (base_quantity > 0),
  unit_cost_minor bigint not null check (unit_cost_minor >= 0),
  line_total_minor bigint not null check (line_total_minor >= 0),
  created_at text not null default iso_now()
);

create table if not exists waste_invoices (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  financial_year_id uuid not null references financial_years(id) on delete restrict,
  waste_number text not null,
  created_by uuid references users(id) on delete set null,
  origin_device_id uuid references devices(id) on delete set null,
  status text not null default 'draft' check (status in ('draft','posted','void')),
  total_cost_minor bigint not null default 0,
  note text,
  occurred_at text not null,
  posted_at text,
  voided_at text,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1,
  unique (entity_id, waste_number)
);

create table if not exists waste_items (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  waste_invoice_id uuid not null references waste_invoices(id) on delete cascade,
  inventory_item_id uuid not null references inventory_items(id) on delete restrict,
  product_unit_id uuid not null references product_units(id) on delete restrict,
  quantity double precision not null check (quantity > 0),
  unit_factor_at_waste double precision not null check (unit_factor_at_waste > 0),
  base_quantity double precision not null check (base_quantity > 0),
  cost_amount_minor bigint not null default 0,
  created_at text not null default iso_now()
);

-- ---------------------------------------------------------------------
-- 5. cash
-- ---------------------------------------------------------------------

create table if not exists cashboxes (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  name text not null,
  current_balance_minor bigint not null default 0,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1,
  unique (entity_id, name)
);

create table if not exists cash_sessions (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  financial_year_id uuid not null references financial_years(id) on delete restrict,
  cashbox_id uuid not null references cashboxes(id) on delete restrict,
  opened_by uuid references users(id) on delete set null,
  closed_by uuid references users(id) on delete set null,
  origin_device_id uuid references devices(id) on delete set null,
  status text not null default 'open' check (status in ('open','closed')),
  opening_amount_minor bigint not null default 0,
  expected_amount_minor bigint,
  counted_amount_minor bigint,
  difference_minor bigint,
  opened_at text not null,
  closed_at text,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now()
);

create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  financial_year_id uuid not null references financial_years(id) on delete restrict,
  cashbox_id uuid not null references cashboxes(id) on delete restrict,
  cash_session_id uuid references cash_sessions(id) on delete set null,
  party_id uuid references parties(id) on delete set null,
  direction text not null check (direction in ('in','out')),
  kind text not null check (kind in ('opening_balance','sale_payment','purchase_payment','sale_refund','purchase_refund','expense','transfer','adjustment','party_payment','other','reversal')),
  amount_minor bigint not null check (amount_minor > 0),
  reference_type text not null,
  reference_id text not null,
  reversal_of_id uuid references transactions(id) on delete restrict,
  note text,
  created_by uuid references users(id) on delete set null,
  origin_device_id uuid references devices(id) on delete set null,
  occurred_at text not null,
  created_at text not null default iso_now()
);

create table if not exists party_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  financial_year_id uuid not null references financial_years(id) on delete restrict,
  party_id uuid not null references parties(id) on delete restrict,
  transaction_id uuid references transactions(id) on delete set null,
  entry_type text not null,
  balance_delta_minor bigint not null,
  reference_type text not null,
  reference_id text not null,
  reversal_of_id uuid references party_ledger_entries(id) on delete restrict,
  note text,
  created_by uuid references users(id) on delete set null,
  origin_device_id uuid references devices(id) on delete set null,
  occurred_at text not null,
  created_at text not null default iso_now()
);

create table if not exists expenses (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  financial_year_id uuid not null references financial_years(id) on delete restrict,
  expense_number text not null,
  cashbox_id uuid not null references cashboxes(id) on delete restrict,
  amount_minor bigint not null check (amount_minor > 0),
  status text not null default 'draft' check (status in ('draft','posted','void')),
  note text,
  created_by uuid references users(id) on delete set null,
  origin_device_id uuid references devices(id) on delete set null,
  occurred_at text not null,
  posted_at text,
  voided_at text,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1,
  unique (entity_id, expense_number)
);

create table if not exists cash_transfers (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  financial_year_id uuid not null references financial_years(id) on delete restrict,
  transfer_number text not null,
  from_cashbox_id uuid not null references cashboxes(id) on delete restrict,
  to_cashbox_id uuid not null references cashboxes(id) on delete restrict,
  amount_minor bigint not null check (amount_minor > 0),
  status text not null default 'draft' check (status in ('draft','posted','void')),
  note text,
  created_by uuid references users(id) on delete set null,
  origin_device_id uuid references devices(id) on delete set null,
  occurred_at text not null,
  posted_at text,
  voided_at text,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1,
  check (from_cashbox_id <> to_cashbox_id),
  unique (entity_id, transfer_number)
);

create table if not exists cash_adjustments (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null references entities(id) on delete cascade,
  financial_year_id uuid not null references financial_years(id) on delete restrict,
  adjustment_number text not null,
  cashbox_id uuid not null references cashboxes(id) on delete restrict,
  direction text not null check (direction in ('in','out')),
  amount_minor bigint not null check (amount_minor > 0),
  status text not null default 'draft' check (status in ('draft','posted','void')),
  note text not null,
  created_by uuid references users(id) on delete set null,
  origin_device_id uuid references devices(id) on delete set null,
  occurred_at text not null,
  posted_at text,
  voided_at text,
  created_at text not null default iso_now(),
  updated_at text not null default iso_now(),
  deleted_at text,
  version integer not null default 1,
  unique (entity_id, adjustment_number)
);

-- ---------------------------------------------------------------------
-- 6. server sync infrastructure
-- ---------------------------------------------------------------------

-- Service-role-only receipt table used to make client push operations
-- idempotent. RLS is enabled below with no authenticated/anon policies.
create table if not exists sync_operation_receipts (
  operation_id uuid primary key,
  entity_id uuid not null references entities(id) on delete cascade,
  device_id uuid references devices(id) on delete set null,
  user_id uuid references users(id) on delete set null,
  aggregate_type text not null,
  aggregate_id uuid not null,
  action text not null,
  request_hash text,
  status text not null default 'processing'
    check (status in ('processing','accepted','rejected','failed')),
  accepted boolean,
  error_message text,
  response_json jsonb,
  received_at text not null default iso_now(),
  completed_at text
);

-- Ordered server-side change feed consumed by pull synchronization.
create table if not exists sync_log (
  seq bigint generated always as identity primary key,
  entity_id uuid not null,
  table_name text not null,
  record_id uuid not null,
  change_type text not null check (change_type in ('insert','update','delete')),
  record_version integer not null default 1,
  payload_json jsonb,
  changed_at text not null default iso_now()
);

-- ---------------------------------------------------------------------
-- 7. indexes
-- ---------------------------------------------------------------------

create index if not exists idx_users_entity on users(entity_id);
create index if not exists idx_users_auth on users(auth_user_id);
create index if not exists idx_devices_entity on devices(entity_id);
create index if not exists idx_financial_years_entity on financial_years(entity_id);
create index if not exists idx_parties_entity on parties(entity_id);
create index if not exists idx_parties_type on parties(entity_id, type);
create index if not exists idx_products_entity on products(entity_id);
create index if not exists idx_products_category on products(category_id);
create index if not exists idx_product_units_product on product_units(product_id);
create index if not exists idx_barcodes_code on barcodes(entity_id, code);
create index if not exists idx_warehouses_entity on warehouses(entity_id);
create index if not exists idx_inventory_item_product_warehouse on inventory_items(entity_id, product_id, warehouse_id);
create index if not exists idx_inventory_movements_item on inventory_movements(inventory_item_id, occurred_at);
create index if not exists idx_inventory_movements_reference on inventory_movements(reference_type, reference_id);
create index if not exists idx_inventory_adjustments_status on inventory_adjustments(entity_id, status);
create index if not exists idx_inventory_transfers_status on inventory_transfers(entity_id, status);
create index if not exists idx_sales_entity_date on sales(entity_id, occurred_at);
create index if not exists idx_sales_status on sales(entity_id, status);
create index if not exists idx_sale_items_sale on sale_items(sale_id);
create index if not exists idx_purchase_entity_date on purchase_invoices(entity_id, occurred_at);
create index if not exists idx_purchase_items_invoice on purchase_items(purchase_invoice_id);
create index if not exists idx_sale_returns_sale on sale_return_invoices(sale_id);
create index if not exists idx_purchase_returns_purchase on purchase_return_invoices(purchase_invoice_id);
create index if not exists idx_waste_status on waste_invoices(entity_id, status);
create index if not exists idx_cashboxes_entity on cashboxes(entity_id);
create index if not exists idx_cash_sessions_cashbox on cash_sessions(cashbox_id, opened_at);
create index if not exists idx_transactions_cashbox_date on transactions(cashbox_id, occurred_at);
create index if not exists idx_transactions_reference on transactions(reference_type, reference_id);
create index if not exists idx_party_ledger_party_date on party_ledger_entries(party_id, occurred_at);
create index if not exists idx_party_ledger_reference on party_ledger_entries(reference_type, reference_id);
create index if not exists idx_expenses_date on expenses(entity_id, occurred_at);
create index if not exists idx_transfers_status on cash_transfers(entity_id, status);
create index if not exists idx_cash_adjustments_status on cash_adjustments(entity_id, status);
create index if not exists idx_sync_receipts_entity_received
  on sync_operation_receipts(entity_id, received_at);
create index if not exists idx_sync_receipts_aggregate
  on sync_operation_receipts(entity_id, aggregate_type, aggregate_id);
create index if not exists idx_sync_log_entity_seq on sync_log(entity_id, seq);
create index if not exists idx_sync_log_record on sync_log(entity_id, table_name, record_id);

create unique index if not exists one_primary_unit_per_product
  on product_units(product_id) where is_primary and deleted_at is null;

-- ---------------------------------------------------------------------
-- 8. trigger functions
-- ---------------------------------------------------------------------

-- bump version + updated_at on every update (tables that have both columns)
create or replace function bump_version() returns trigger
language plpgsql as $$
begin
  new.version := coalesce(old.version, 0) + 1;
  new.updated_at := iso_now();
  return new;
end;
$$;

create or replace function bump_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := iso_now();
  return new;
end;
$$;

-- block any mutation on append-only ledger tables
create or replace function guard_no_mutation() returns trigger
language plpgsql as $$
begin
  raise exception 'table % is append-only; mutations are not allowed', TG_TABLE_NAME
    using errcode = '25006';
end;
$$;

-- posted/void documents (and status docs) are immutable
create or replace function guard_document_update() returns trigger
language plpgsql as $$
declare
  v_old jsonb := to_jsonb(old);
  v_new jsonb := to_jsonb(new);
begin
  if (v_old ->> 'deleted_at') is not null then
    raise exception 'row in % is soft-deleted', TG_TABLE_NAME;
  end if;
  if (v_old ->> 'status') = 'void' then
    raise exception 'voided document in % is immutable', TG_TABLE_NAME;
  end if;
  if (v_old ->> 'status') = 'posted' and (v_new ->> 'status') <> 'void' then
    raise exception 'posted document in % is immutable', TG_TABLE_NAME;
  end if;
  return new;
end;
$$;

-- write a change-feed row for every business-table mutation
create or replace function sync_log_after_any() returns trigger
language plpgsql as $$
declare
  v_new jsonb := to_jsonb(new);
  v_old jsonb := to_jsonb(old);
  v_change text := TG_OP;
  v_entity uuid := (v_new ->> 'entity_id')::uuid;
begin
  if TG_OP = 'DELETE' then
    v_new := to_jsonb(old);
    v_entity := (v_new ->> 'entity_id')::uuid;
    v_change := 'delete';
  elsif TG_OP = 'UPDATE'
    and v_new ? 'deleted_at'
    and (v_new ->> 'deleted_at') is not null
    and (v_old ->> 'deleted_at') is null then
    v_change := 'delete';
  end if;

  insert into sync_log (entity_id, table_name, record_id, change_type, record_version, payload_json, changed_at)
  values (
    v_entity,
    TG_TABLE_NAME,
    (v_new ->> 'id')::uuid,
    v_change,
    coalesce((v_new ->> 'version')::int, 1),
    v_new,
    iso_now()
  );
  return null;
end;
$$;

-- ---------------------------------------------------------------------
-- 9. attach triggers
-- ---------------------------------------------------------------------

do $$
declare t text;
begin
  -- versioned soft-delete catalog/core tables
  foreach t in array array[
    'parties','categories','products','product_specifications','product_units',
    'barcodes','warehouses','cashboxes','financial_years'
  ] loop
    execute format('drop trigger if exists trg_bump_version_%s on %s', t, t);
    execute format('create trigger trg_bump_version_%s before update on %s for each row execute function bump_version()', t, t);
    execute format('drop trigger if exists trg_sync_log_%s on %s', t, t);
    execute format('create trigger trg_sync_log_%s after insert or update on %s for each row execute function sync_log_after_any()', t, t);
  end loop;

  -- status documents (draft/posted/void)
  foreach t in array array[
    'sales','purchase_invoices','sale_return_invoices','purchase_return_invoices',
    'waste_invoices','inventory_adjustments','inventory_transfers','expenses',
    'cash_transfers','cash_adjustments'
  ] loop
    execute format('drop trigger if exists trg_bump_version_%s on %s', t, t);
    execute format('create trigger trg_bump_version_%s before update on %s for each row execute function bump_version()', t, t);
    execute format('drop trigger if exists trg_guard_doc_%s on %s', t, t);
    execute format('create trigger trg_guard_doc_%s before update on %s for each row execute function guard_document_update()', t, t);
    execute format('drop trigger if exists trg_sync_log_%s on %s', t, t);
    execute format('create trigger trg_sync_log_%s after insert or update on %s for each row execute function sync_log_after_any()', t, t);
  end loop;

  -- inventory_items (versioned, no soft-delete)
  execute 'drop trigger if exists trg_bump_version_inventory_items on inventory_items';
  execute 'create trigger trg_bump_version_inventory_items before update on inventory_items for each row execute function bump_version()';
  execute 'drop trigger if exists trg_sync_log_inventory_items on inventory_items';
  execute 'create trigger trg_sync_log_inventory_items after insert or update on inventory_items for each row execute function sync_log_after_any()';

  -- append-only ledgers (insert-only, no update/delete)
  foreach t in array array[
    'inventory_movements','transactions','party_ledger_entries',
    'sale_items','purchase_items','sale_return_items','purchase_return_items',
    'waste_items','inventory_adjustment_items','inventory_transfer_items'
  ] loop
    execute format('drop trigger if exists trg_guard_append_%s on %s', t, t);
    execute format('create trigger trg_guard_append_%s before update or delete on %s for each row execute function guard_no_mutation()', t, t);
    execute format('drop trigger if exists trg_sync_log_%s on %s', t, t);
    execute format('create trigger trg_sync_log_%s after insert on %s for each row execute function sync_log_after_any()', t, t);
  end loop;

  -- devices / cash_sessions
  execute 'drop trigger if exists trg_bump_version_devices on devices';
  execute 'create trigger trg_bump_version_devices before update on devices for each row execute function bump_version()';
  execute 'drop trigger if exists trg_sync_log_devices on devices';
  execute 'create trigger trg_sync_log_devices after insert or update on devices for each row execute function sync_log_after_any()';

  execute 'drop trigger if exists trg_bump_updated_at_cash_sessions on cash_sessions';
  execute 'create trigger trg_bump_updated_at_cash_sessions before update on cash_sessions for each row execute function bump_updated_at()';
  execute 'drop trigger if exists trg_sync_log_cash_sessions on cash_sessions';
  execute 'create trigger trg_sync_log_cash_sessions after insert or update on cash_sessions for each row execute function sync_log_after_any()';

  -- users / entities (custom policies below)
  execute 'drop trigger if exists trg_bump_version_users on users';
  execute 'create trigger trg_bump_version_users before update on users for each row execute function bump_version()';
  execute 'drop trigger if exists trg_sync_log_users on users';
  execute 'create trigger trg_sync_log_users after insert or update on users for each row execute function sync_log_after_any()';

  execute 'drop trigger if exists trg_bump_version_entities on entities';
  execute 'create trigger trg_bump_version_entities before update on entities for each row execute function bump_version()';
  execute 'drop trigger if exists trg_sync_log_entities on entities';
  execute 'create trigger trg_sync_log_entities after insert or update on entities for each row execute function sync_log_after_any()';
end $$;

-- ---------------------------------------------------------------------
-- 10. row-level security
-- ---------------------------------------------------------------------

alter table entities enable row level security;
alter table users enable row level security;
alter table devices enable row level security;
alter table financial_years enable row level security;
alter table parties enable row level security;
alter table categories enable row level security;
alter table products enable row level security;
alter table product_specifications enable row level security;
alter table product_units enable row level security;
alter table barcodes enable row level security;
alter table warehouses enable row level security;
alter table inventory_items enable row level security;
alter table inventory_movements enable row level security;
alter table inventory_adjustments enable row level security;
alter table inventory_adjustment_items enable row level security;
alter table inventory_transfers enable row level security;
alter table inventory_transfer_items enable row level security;
alter table sales enable row level security;
alter table sale_items enable row level security;
alter table purchase_invoices enable row level security;
alter table purchase_items enable row level security;
alter table sale_return_invoices enable row level security;
alter table sale_return_items enable row level security;
alter table purchase_return_invoices enable row level security;
alter table purchase_return_items enable row level security;
alter table waste_invoices enable row level security;
alter table waste_items enable row level security;
alter table cashboxes enable row level security;
alter table cash_sessions enable row level security;
alter table transactions enable row level security;
alter table party_ledger_entries enable row level security;
alter table expenses enable row level security;
alter table cash_transfers enable row level security;
alter table cash_adjustments enable row level security;
alter table sync_operation_receipts enable row level security;
alter table sync_log enable row level security;

do $$
declare t text;
begin
  -- standard entity-scoped tables: select/insert/update
  foreach t in array array[
    'parties','categories','products','product_specifications','product_units',
    'barcodes','warehouses','cashboxes','financial_years','inventory_items',
    'sales','purchase_invoices','sale_return_invoices','purchase_return_invoices',
    'waste_invoices','inventory_adjustments','inventory_transfers','expenses',
    'cash_transfers','cash_adjustments','cash_sessions','devices'
  ] loop
    execute format('drop policy if exists select_%s on %s', t, t);
    execute format('create policy select_%s on %s for select to authenticated using (entity_id = auth_entity_id())', t, t);
    execute format('drop policy if exists insert_%s on %s', t, t);
    execute format('create policy insert_%s on %s for insert to authenticated with check (entity_id = auth_entity_id())', t, t);
    execute format('drop policy if exists update_%s on %s', t, t);
    execute format('create policy update_%s on %s for update to authenticated using (entity_id = auth_entity_id()) with check (entity_id = auth_entity_id())', t, t);
  end loop;

  -- append-only ledgers: select/insert only (server rules block updates/deletes)
  foreach t in array array[
    'inventory_movements','transactions','party_ledger_entries',
    'sale_items','purchase_items','sale_return_items','purchase_return_items',
    'waste_items','inventory_adjustment_items','inventory_transfer_items'
  ] loop
    execute format('drop policy if exists select_%s on %s', t, t);
    execute format('create policy select_%s on %s for select to authenticated using (entity_id = auth_entity_id())', t, t);
    execute format('drop policy if exists insert_%s on %s', t, t);
    execute format('create policy insert_%s on %s for insert to authenticated with check (entity_id = auth_entity_id())', t, t);
  end loop;
end $$;

-- entities: see only own entity; any authenticated user may create (onboarding)
drop policy if exists select_entities on entities;
create policy select_entities on entities for select to authenticated using (id = auth_entity_id());
drop policy if exists insert_entities on entities;
create policy insert_entities on entities for insert to authenticated with check (auth.uid() is not null);
drop policy if exists update_entities on entities;
create policy update_entities on entities for update to authenticated using (id = auth_entity_id()) with check (id = auth_entity_id());

-- users: your own row is always visible/editable
drop policy if exists select_users on users;
create policy select_users on users for select to authenticated using (entity_id = auth_entity_id() or auth_user_id = auth.uid());
drop policy if exists insert_users on users;
create policy insert_users on users for insert to authenticated with check (auth_user_id = auth.uid());
drop policy if exists update_users on users;
create policy update_users on users for update to authenticated using (entity_id = auth_entity_id() or auth_user_id = auth.uid()) with check (entity_id = auth_entity_id() or auth_user_id = auth.uid());

-- sync_log: read-only via API (writes happen only through table triggers)
drop policy if exists select_sync_log on sync_log;
create policy select_sync_log on sync_log for select to authenticated using (entity_id = auth_entity_id());

-- sync_operation_receipts intentionally has no anon/authenticated policies.
-- It is accessed only by the trusted push endpoint using the service role.

-- ---------------------------------------------------------------------
-- 11. sync RPC (pull change feed, mirrors SyncTransport.pull contract)
-- ---------------------------------------------------------------------

create or replace function get_sync_changes(p_entity uuid, p_after bigint)
returns table (
  server_seq bigint,
  table_name text,
  record_id uuid,
  change_type text,
  record_version integer,
  payload_json jsonb,
  changed_at text
)
language sql stable security definer set search_path = public as $$
  select seq, table_name, record_id, change_type, record_version, payload_json, changed_at
  from sync_log
  where entity_id = p_entity
    and seq > p_after
    and auth_entity_id() = p_entity
  order by seq asc
  limit 1000;
$$;

create or replace function get_last_server_seq(p_entity uuid)
returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(max(seq), 0)
  from sync_log
  where entity_id = p_entity
    and auth_entity_id() = p_entity;
$$;

grant execute on function get_sync_changes(uuid, bigint) to authenticated;
grant execute on function get_last_server_seq(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 12. seed (optional; run once)
-- ---------------------------------------------------------------------

insert into entities (id, name, currency_code, timezone)
values ('00000000-0000-0000-0000-000000000001', 'Default Business', 'USD', 'UTC')
on conflict (id) do nothing;
