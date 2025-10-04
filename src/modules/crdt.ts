import * as A from 'automerge';

type Doc = { title: string; notes: string };

export function initNotes(textarea: HTMLTextAreaElement, docIdEl: HTMLElement) {
  let doc: A.Doc<Doc> = A.from<Doc>({ title: 'Untitled', notes: '' });
  const id = A.getActorId(doc);
  docIdEl.textContent = id;

  textarea.value = doc.notes;
  textarea.addEventListener('input', () => {
    doc = A.change(doc, d => { d.notes = textarea.value; });
    // Persist to OPFS or sync in future
  });
}
