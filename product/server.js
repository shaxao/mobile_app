const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const path = require('path');
const Database = require('better-sqlite3');

const dbPath = path.join(__dirname, 'data.sqlite');
const db = new Database(dbPath);

// 初始化数据库表
db.exec(`
CREATE TABLE IF NOT EXISTS records (
  id INTEGER PRIMARY KEY,
  borrower TEXT NOT NULL,
  borrowDate TEXT NOT NULL,
  borrowUnit TEXT NOT NULL,
  sourceUnit TEXT NOT NULL,
  sourcePerson TEXT NOT NULL,
  notes TEXT,
  status TEXT NOT NULL,
  returnDate TEXT,
  returnNotes TEXT
);

CREATE TABLE IF NOT EXISTS items (
  id INTEGER PRIMARY KEY,
  recordId INTEGER NOT NULL,
  name TEXT NOT NULL,
  spec TEXT,
  quantity INTEGER NOT NULL,
  returnedQuantity INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(recordId) REFERENCES records(id) ON DELETE CASCADE
);
`);

const app = express();
app.use(cors());
app.use(bodyParser.json({ limit: '1mb' }));
// 静态托管原始前端文件（index.html、styles.css、script.js）
app.use(express.static(__dirname));
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// 工具函数
function computeStatus(items) {
  if (!items || items.length === 0) return 'pending';
  const allReturned = items.every(it => (it.returnedQuantity || 0) >= it.quantity);
  const anyReturned = items.some(it => (it.returnedQuantity || 0) > 0 && (it.returnedQuantity || 0) < it.quantity);
  if (allReturned) return 'returned';
  if (anyReturned) return 'partial';
  return 'pending';
}

// API: 获取所有记录
app.get('/api/records', (req, res) => {
  const records = db.prepare('SELECT * FROM records ORDER BY id DESC').all();
  const itemsStmt = db.prepare('SELECT * FROM items WHERE recordId = ? ORDER BY id ASC');
  const result = records.map(r => ({ ...r, items: itemsStmt.all(r.id) }));
  res.json(result);
});

// API: 新增记录
app.post('/api/records', (req, res) => {
  try {
    const { borrower, borrowDate, borrowUnit, sourceUnit, sourcePerson, notes, items } = req.body;
    if (!borrower || !borrowDate || !borrowUnit || !sourceUnit || !sourcePerson) {
      return res.status(400).json({ error: '缺少必要字段' });
    }
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: '至少需要一件商品' });
    }
    const status = computeStatus(items);
    const insertRecord = db.prepare(`INSERT INTO records (borrower, borrowDate, borrowUnit, sourceUnit, sourcePerson, notes, status) VALUES (?,?,?,?,?,?,?)`);
    const info = insertRecord.run(borrower, borrowDate, borrowUnit, sourceUnit, sourcePerson, notes || '', status);
    const recordId = info.lastInsertRowid;
    const insertItem = db.prepare(`INSERT INTO items (recordId, name, spec, quantity, returnedQuantity) VALUES (?,?,?,?,?)`);
    const insertMany = db.transaction((itemsArr) => {
      for (const it of itemsArr) {
        insertItem.run(recordId, it.name, it.spec || '', parseInt(it.quantity, 10), parseInt(it.returnedQuantity || 0, 10));
      }
    });
    insertMany(items);
    const newRecord = db.prepare('SELECT * FROM records WHERE id = ?').get(recordId);
    const recordItems = db.prepare('SELECT * FROM items WHERE recordId = ? ORDER BY id ASC').all(recordId);
    res.status(201).json({ ...newRecord, items: recordItems });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// API: 删除记录
app.delete('/api/records/:id', (req, res) => {
  const id = parseInt(req.params.id, 10);
  const delItems = db.prepare('DELETE FROM items WHERE recordId = ?');
  const delRecord = db.prepare('DELETE FROM records WHERE id = ?');
  const txn = db.transaction((rid) => {
    delItems.run(rid);
    delRecord.run(rid);
  });
  try {
    txn(id);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// API: 部分还货
app.post('/api/records/:id/return', (req, res) => {
  const id = parseInt(req.params.id, 10);
  const { returns, returnDate, returnNotes } = req.body; // returns: [{itemId, qty}]
  if (!Array.isArray(returns)) return res.status(400).json({ error: 'returns 必须为数组' });
  try {
    const items = db.prepare('SELECT * FROM items WHERE recordId = ?').all(id);
    const updateItem = db.prepare('UPDATE items SET returnedQuantity = ? WHERE id = ?');
    const applyReturns = db.transaction(() => {
      for (const r of returns) {
        const it = items.find(i => i.id === r.itemId);
        if (!it) continue;
        const remaining = Math.max(0, it.quantity - it.returnedQuantity);
        const applyQty = Math.min(remaining, parseInt(r.qty || 0, 10));
        const newReturned = it.returnedQuantity + applyQty;
        updateItem.run(newReturned, it.id);
      }
    });
    applyReturns();
    const updatedItems = db.prepare('SELECT * FROM items WHERE recordId = ?').all(id);
    const status = computeStatus(updatedItems);
    db.prepare('UPDATE records SET status = ?, returnDate = ?, returnNotes = ? WHERE id = ?')
      .run(status, returnDate || null, returnNotes || '', id);
    const updatedRecord = db.prepare('SELECT * FROM records WHERE id = ?').get(id);
    res.json({ ...updatedRecord, items: updatedItems });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 启动服务
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`API server listening on http://127.0.0.1:${PORT}`);
});