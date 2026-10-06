-- Tabela de leads da landing Bem Estar (Postgres / Supabase)
create extension if not exists pgcrypto;

create table if not exists leads_bemestar (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  nome         text,
  telefone     text,              -- E.164 sem "+": 55 + DDD + número
  empresa      text,
  cidade       text,
  prazo        text,
  itens        jsonb not null default '[]'::jsonb,
  itens_hash   text,              -- usado na deduplicação (telefone + itens em 10 min)
  origem       text,
  utms         jsonb not null default '{}'::jsonb,
  ip           text,
  status       text not null default 'novo',  -- novo | respondido | erro_envio | ...
  lembrado_em  timestamptz         -- último lembrete de follow-up enviado ao Daniel
);

create index if not exists leads_bemestar_dedup_idx  on leads_bemestar (telefone, itens_hash, created_at desc);
create index if not exists leads_bemestar_status_idx on leads_bemestar (status, created_at);
