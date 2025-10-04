export async function saveFile(path: string, data: ArrayBuffer) {
  // @ts-ignore
  const root = await navigator.storage.getDirectory();
  const parts = path.split('/').filter(Boolean);
  let dir = root;
  for (let i = 0; i < parts.length - 1; i++) {
    dir = await dir.getDirectoryHandle(parts[i], { create: true });
  }
  const fh = await dir.getFileHandle(parts[parts.length - 1], { create: true });
  const stream = await fh.createWritable();
  await stream.write(data);
  await stream.close();
}

export async function listFiles(folder = ''): Promise<string[]> {
  // @ts-ignore
  const root = await navigator.storage.getDirectory();
  const parts = folder.split('/').filter(Boolean);
  let dir = root;
  for (const p of parts) {
    dir = await dir.getDirectoryHandle(p, { create: true });
  }
  const out: string[] = [];
  // @ts-ignore
  for await (const [name, handle] of dir.entries()) {
    if (handle.kind === 'file') out.push(`${folder ? folder + '/' : ''}${name}`);
  }
  return out.sort();
}

export async function loadLatest(folder = ''): Promise<ArrayBuffer | null> {
  const files = await listFiles(folder);
  if (!files.length) return null;
  const last = files[files.length - 1];
  // @ts-ignore
  const root = await navigator.storage.getDirectory();
  const parts = last.split('/').filter(Boolean);
  let dir = root;
  for (let i = 0; i < parts.length - 1; i++) {
    dir = await dir.getDirectoryHandle(parts[i], { create: false });
  }
  const fh = await dir.getFileHandle(parts[parts.length - 1], { create: false });
  const file = await fh.getFile();
  return await file.arrayBuffer();
}
