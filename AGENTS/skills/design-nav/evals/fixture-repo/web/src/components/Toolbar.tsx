export function Toolbar({ onSave, onCancel }: { onSave: () => void; onCancel: () => void }) {
  return (
    <div className="toolbar">
      <button onClick={onCancel}>Cancel</button>
      <button onClick={onSave}>Save</button>
    </div>
  );
}
