#!/usr/bin/env node
/**
 * TravianTimer Codebase Indexer
 *
 * Liest alle Code-Dateien, erstellt Embeddings via OpenAI,
 * und speichert sie in Supabase für RAG-basierte Suche.
 *
 * Usage: node indexer/index.mjs
 *
 * Benötigt in discord-bot/.env:
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
 * Zusätzlich:
 *   OPENAI_API_KEY (in discord-bot/.env oder als Env-Variable)
 */

import { createClient } from '@supabase/supabase-js';
import { readFileSync, readdirSync, statSync, existsSync } from 'fs';
import { join, relative, extname, basename } from 'path';
import { config } from 'dotenv';

// .env laden aus discord-bot/
const projectRoot = decodeURIComponent(new URL('..', import.meta.url).pathname);
config({ path: join(projectRoot, 'discord-bot', '.env') });

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error('❌ SUPABASE_URL und SUPABASE_SERVICE_ROLE_KEY müssen in discord-bot/.env gesetzt sein');
  process.exit(1);
}
if (!OPENAI_API_KEY) {
  console.error('❌ OPENAI_API_KEY muss gesetzt sein (in discord-bot/.env oder als ENV)');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// ============================================
// Konfiguration
// ============================================

const FILE_EXTENSIONS = ['.swift', '.sql', '.ts', '.js', '.json', '.md'];
const IGNORE_DIRS = ['node_modules', '.build', 'DerivedData', '.git', 'Pods', 'indexer'];
const IGNORE_FILES = ['package-lock.json', '.env', 'yarn.lock'];
const MAX_CHUNK_SIZE = 1500; // Zeichen pro Chunk
const CHUNK_OVERLAP = 200;  // Überlappung zwischen Chunks
const EMBEDDING_MODEL = 'text-embedding-3-small';
const BATCH_SIZE = 20; // Embeddings pro API-Call

// ============================================
// Dateien sammeln
// ============================================

function collectFiles(dir, files = []) {
  const entries = readdirSync(dir);
  for (const entry of entries) {
    const fullPath = join(dir, entry);

    if (IGNORE_DIRS.includes(entry)) continue;
    if (entry.startsWith('.') && entry !== '.env.example') continue;

    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      collectFiles(fullPath, files);
    } else if (FILE_EXTENSIONS.includes(extname(entry)) && !IGNORE_FILES.includes(entry)) {
      // Nur Dateien unter 50KB indexieren
      if (stat.size < 50000) {
        files.push(fullPath);
      }
    }
  }
  return files;
}

// ============================================
// Intelligent Chunking
// ============================================

function chunkFile(content, filePath) {
  const ext = extname(filePath);
  const chunks = [];

  // Swift: Nach Funktionen/Klassen/Structs splitten
  if (ext === '.swift') {
    return chunkByPatterns(content, filePath, [
      /^(class |struct |enum |protocol |extension |func |var |let )/m,
      /^    (func |var |let |@)/m,
    ]);
  }

  // SQL: Nach Statements splitten
  if (ext === '.sql') {
    return chunkByStatements(content, filePath);
  }

  // TS/JS: Nach Funktionen/Exports splitten
  if (ext === '.ts' || ext === '.js') {
    return chunkByPatterns(content, filePath, [
      /^(export |async function |function |const |class |app\.|router\.)/m,
    ]);
  }

  // Alles andere: Nach Zeichenlänge
  return chunkBySize(content, filePath);
}

function chunkByPatterns(content, filePath, patterns) {
  const lines = content.split('\n');
  const chunks = [];
  let currentChunk = [];
  let currentSize = 0;

  for (const line of lines) {
    const isBreakpoint = patterns.some(p => p.test(line));

    if (isBreakpoint && currentSize > 200) {
      // Neuen Chunk starten
      chunks.push(currentChunk.join('\n'));
      // Überlappung: letzte paar Zeilen mitnehmen
      const overlapLines = currentChunk.slice(-3);
      currentChunk = [...overlapLines, line];
      currentSize = currentChunk.join('\n').length;
    } else {
      currentChunk.push(line);
      currentSize += line.length + 1;
    }

    // Maximale Chunk-Größe einhalten
    if (currentSize > MAX_CHUNK_SIZE) {
      chunks.push(currentChunk.join('\n'));
      const overlapLines = currentChunk.slice(-3);
      currentChunk = [...overlapLines];
      currentSize = currentChunk.join('\n').length;
    }
  }

  if (currentChunk.length > 0) {
    chunks.push(currentChunk.join('\n'));
  }

  return chunks.filter(c => c.trim().length > 50).map((chunk, i) => ({
    content: chunk,
    metadata: {
      file_path: relative(projectRoot, filePath),
      language: extname(filePath).slice(1),
      chunk_index: i,
      total_chunks: chunks.length,
      file_name: basename(filePath),
    }
  }));
}

function chunkByStatements(content, filePath) {
  // SQL: Nach leeren Zeilen oder Kommentar-Blöcken splitten
  const sections = content.split(/\n\n+/);
  const chunks = [];
  let currentChunk = '';

  for (const section of sections) {
    if (currentChunk.length + section.length > MAX_CHUNK_SIZE && currentChunk.length > 100) {
      chunks.push(currentChunk);
      currentChunk = section;
    } else {
      currentChunk += (currentChunk ? '\n\n' : '') + section;
    }
  }
  if (currentChunk.trim()) chunks.push(currentChunk);

  return chunks.filter(c => c.trim().length > 50).map((chunk, i) => ({
    content: chunk,
    metadata: {
      file_path: relative(projectRoot, filePath),
      language: 'sql',
      chunk_index: i,
      total_chunks: chunks.length,
      file_name: basename(filePath),
    }
  }));
}

function chunkBySize(content, filePath) {
  const chunks = [];
  for (let i = 0; i < content.length; i += MAX_CHUNK_SIZE - CHUNK_OVERLAP) {
    const chunk = content.slice(i, i + MAX_CHUNK_SIZE);
    if (chunk.trim().length > 50) {
      chunks.push({
        content: chunk,
        metadata: {
          file_path: relative(projectRoot, filePath),
          language: extname(filePath).slice(1) || 'text',
          chunk_index: chunks.length,
          file_name: basename(filePath),
        }
      });
    }
  }
  chunks.forEach(c => c.metadata.total_chunks = chunks.length);
  return chunks;
}

// ============================================
// OpenAI Embeddings
// ============================================

async function generateEmbeddings(texts) {
  const response = await fetch('https://api.openai.com/v1/embeddings', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: EMBEDDING_MODEL,
      input: texts,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OpenAI API Fehler: ${response.status} - ${error}`);
  }

  const data = await response.json();
  return data.data.map(d => d.embedding);
}

// ============================================
// Supabase Upsert
// ============================================

async function clearExistingEmbeddings() {
  const { error } = await supabase
    .from('code_embeddings')
    .delete()
    .neq('id', '00000000-0000-0000-0000-000000000000'); // Alles löschen

  if (error) throw new Error(`Fehler beim Löschen: ${error.message}`);
}

async function insertEmbeddings(chunks, embeddings) {
  const rows = chunks.map((chunk, i) => ({
    content: chunk.content,
    metadata: chunk.metadata,
    embedding: JSON.stringify(embeddings[i]),
  }));

  const { error } = await supabase
    .from('code_embeddings')
    .insert(rows);

  if (error) throw new Error(`Fehler beim Einfügen: ${error.message}`);
}

// ============================================
// Main
// ============================================

async function main() {
  console.log('🔍 Sammle Code-Dateien...');
  const files = collectFiles(projectRoot);
  console.log(`   ${files.length} Dateien gefunden`);

  // Alle Dateien chunken
  console.log('✂️  Erstelle Chunks...');
  const allChunks = [];
  for (const file of files) {
    try {
      const content = readFileSync(file, 'utf-8');
      const chunks = chunkFile(content, file);
      allChunks.push(...chunks);
    } catch (err) {
      console.warn(`   ⚠️ Überspringe ${basename(file)}: ${err.message}`);
    }
  }
  console.log(`   ${allChunks.length} Chunks erstellt`);

  // Alte Embeddings löschen
  console.log('🗑️  Lösche alte Embeddings...');
  await clearExistingEmbeddings();

  // Embeddings generieren in Batches
  console.log(`🧠 Generiere Embeddings (${Math.ceil(allChunks.length / BATCH_SIZE)} Batches)...`);

  for (let i = 0; i < allChunks.length; i += BATCH_SIZE) {
    const batch = allChunks.slice(i, i + BATCH_SIZE);
    const texts = batch.map(c => `${c.metadata.file_path}\n\n${c.content}`);

    try {
      const embeddings = await generateEmbeddings(texts);
      await insertEmbeddings(batch, embeddings);

      const progress = Math.min(i + BATCH_SIZE, allChunks.length);
      console.log(`   ✅ ${progress}/${allChunks.length} Chunks verarbeitet`);
    } catch (err) {
      console.error(`   ❌ Batch-Fehler bei Chunk ${i}: ${err.message}`);
    }

    // Rate limiting: 100ms Pause zwischen Batches
    await new Promise(r => setTimeout(r, 100));
  }

  // Verifizieren
  const { count } = await supabase
    .from('code_embeddings')
    .select('*', { count: 'exact', head: true });

  console.log(`\n🎉 Fertig! ${count} Embeddings in Supabase gespeichert.`);
  console.log('   Das KI-Team kann jetzt deine Codebase durchsuchen!');
}

main().catch(err => {
  console.error('❌ Fehler:', err.message);
  process.exit(1);
});
