-- ============================================
-- 042: Code Embeddings für KI-Team RAG
-- ============================================
-- Ermöglicht dem n8n KI-Team, die Codebase
-- semantisch zu durchsuchen via Vector Search.
-- ============================================

-- 1. pgvector Extension aktivieren
create extension if not exists vector
  with schema extensions;

-- 2. Embeddings-Tabelle
create table public.code_embeddings (
  id uuid primary key default gen_random_uuid(),
  content text not null,
  metadata jsonb not null default '{}',
  -- file_path, language, chunk_index, file_type
  embedding extensions.vector(1536), -- OpenAI text-embedding-3-small
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. Index für schnelle Vektor-Suche (cosine similarity)
create index on public.code_embeddings
  using ivfflat (embedding extensions.vector_cosine_ops)
  with (lists = 100);

-- 4. Suchfunktion für n8n Vector Store
create or replace function public.match_code_embeddings(
  query_embedding extensions.vector(1536),
  match_count int default 5,
  filter jsonb default '{}'
)
returns table (
  id uuid,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
begin
  return query
  select
    ce.id,
    ce.content,
    ce.metadata,
    1 - (ce.embedding <=> query_embedding) as similarity
  from public.code_embeddings ce
  where ce.metadata @> filter
  order by ce.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- 5. RLS: Nur Service Role darf schreiben (n8n nutzt Service Role Key)
alter table public.code_embeddings enable row level security;

-- Lesen für alle authentifizierten User
create policy "code_embeddings_select"
  on public.code_embeddings for select
  to authenticated
  using (true);

-- Schreiben nur via Service Role (n8n)
-- (kein Policy = kein Zugriff für normale User)

comment on table public.code_embeddings is
  'Vektor-Embeddings der TravianTimer Codebase für RAG-basierte Suche durch das KI-Team';
