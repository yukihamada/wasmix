export type JournalOp = { ts: number; kind: string; payload: unknown };

async function rootDir() {
  // @ts-ignore
  return await navigator.storage.getDirectory();
}

export async function append(projectId: string, op: JournalOp) {
  const dir = await ensureDir(`projects/${projectId}/journal`);
  const name = `${op.ts}-${op.kind}.log`;
  const fh = await dir.getFileHandle(name, { create: true });
  const w = await fh.createWritable();
  await w.write(new TextEncoder().encode(JSON.stringify(op) + "\n"));
  await w.close();
}

export async function snapshot(projectId: string, data: ArrayBuffer) {
  const dir = await ensureDir(`projects/${projectId}/snapshots`);
  const fh = await dir.getFileHandle(`${Date.now()}.bin`, { create: true });
  const w = await fh.createWritable();
  await w.write(data);
  await w.close();
}

export async function replay(projectId: string): Promise<JournalOp[]> {
  const dir = await ensureDir(`projects/${projectId}/journal`);
  const out: JournalOp[] = [];
  // @ts-ignore
  for await (const [name, handle] of dir.entries()) {
    if (handle.kind !== 'file' || !name.endsWith('.log')) continue;
    const f = await handle.getFile();
    const txt = await f.text();
    txt.split(/\n/).filter(Boolean).forEach(line => {
      try { out.push(JSON.parse(line)); } catch {}
    });
  }
  out.sort((a,b) => a.ts - b.ts);
  return out;
}

async function ensureDir(path: string): Promise<any> {
  const parts = path.split('/').filter(Boolean);
  let d = await rootDir();
  for (const p of parts) {
    d = await d.getDirectoryHandle(p, { create: true });
  }
  return d;
}
