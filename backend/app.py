from flask import Flask, jsonify, request
from flask_cors import CORS
import os, sys
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import getBanBiao as gb
from datetime import datetime, timedelta
import sqlite3
from typing import List, Dict, Any

app = Flask(__name__)
CORS(app)

@app.get('/api/v1/borrow/stats')
def borrow_stats():
  date = request.args.get('date')
  data = gb.get_banbiao_data(date)
  return jsonify(data)

@app.post('/api/v1/products')
def products():
  payload_in = request.json or {}
  seldate = int(payload_in.get('seldate', 0))
  chooseData = payload_in.get('chooseData')
  custom_start_date = payload_in.get('custom_start_date')
  custom_end_date = payload_in.get('custom_end_date')
  data = gb._fetch_products(custom_start_date, custom_end_date, seldate, chooseData)
  return jsonify({'data': data})

@app.get('/api/v1/weekly-sales-summary')
def weekly_sales_summary():
  start_date = request.args.get('start_date')
  data = gb.get_weekly_sales_summary(start_date)
  return jsonify(data)
@app.get('/api/v1/staff/weekly-schedule')
def staff_weekly_schedule():
  name = (request.args.get('name') or '').strip()
  start_date = (request.args.get('start_date') or '').strip()
  if not start_date:
    start_date = datetime.today().strftime('%Y-%m-%d')
  try:
    base = datetime.strptime(start_date, '%Y-%m-%d')
  except Exception:
    return jsonify({'error': 'start_date 格式应为 YYYY-MM-DD'}), 400

  week = []
  for i in range(7):
    d = base + timedelta(days=i)
    ds = d.strftime('%Y-%m-%d')
    try:
      ban = gb.get_banbiao_data(ds) or {}
      staff_list = ban.get('staffList') or []
      entry = None
      for s in staff_list:
        # 支持模糊包含匹配，避免姓名空格差异
        sn = str(s.get('staffNm') or '')
        if not name or (sn and (name in sn or sn in name)):
          entry = s
          break
      item = {
        'date': ds,
        'weekday': ['星期一','星期二','星期三','星期四','星期五','星期六','星期日'][d.weekday()],
      }
      if entry:
        # 岗位与休息信息字段兼容多种命名
        position = entry.get('postNm') or entry.get('position') or entry.get('岗位')
        break_start = entry.get('breakStart') or entry.get('restStart') or entry.get('休息开始')
        break_end = entry.get('breakEnd') or entry.get('restEnd') or entry.get('休息结束')
        break_time = None
        if break_start or break_end:
          bs = str(break_start or '')
          be = str(break_end or '')
          break_time = f"{bs}-{be}".strip('-')

        def _parse_hhmm(s):
          try:
            if s is None:
              return None
            s = str(s).replace(':','')
            if len(s) < 3:
              return None
            h = int(s[:2])
            m = int(s[2:4]) if len(s) >= 4 else 0
            return h*60 + m
          except Exception:
            return None

        def _diff_minutes(start, end):
          if start is None or end is None:
            return 0
          diff = end - start
          if diff < 0:
            diff += 24*60
          return diff

        ss = _parse_hhmm(entry.get('shiftStart'))
        se = _parse_hhmm(entry.get('shiftEnd'))
        bs_min = _parse_hhmm(break_start)
        be_min = _parse_hhmm(break_end)
        total_min = _diff_minutes(ss, se)
        break_min = _diff_minutes(bs_min, be_min)
        labor_hours = round(max(0, total_min - break_min) / 60, 2)
        break_hours = round(break_min / 60, 2)

        item.update({
          'name': entry.get('staffNm'),
          'shiftStart': entry.get('shiftStart'),
          'shiftEnd': entry.get('shiftEnd'),
          'laborTime': entry.get('laborTime'),
          'laborHours': labor_hours,
          'position': position,
          'breakTime': break_time,
          'breakHours': break_hours,
          'has_data': True,
        })
      else:
        item.update({'has_data': False})
      week.append(item)
    except Exception:
      week.append({'date': ds, 'weekday': ['星期一','星期二','星期三','星期四','星期五','星期六','星期日'][d.weekday()], 'has_data': False})

  return jsonify({'name': name, 'start_date': start_date, 'weekly_schedule': week})

@app.get('/api/v1/weekly-schedule')
def staff_weekly_schedule_alias():
  return staff_weekly_schedule()

@app.get('/api/v1/attendance')
def attendance():
  year_month = request.args.get('year_month')
  name = request.args.get('name')
  code = request.args.get('code')
  data = gb.get_attendance_data(year_month, name, code)
  return jsonify(data)

@app.get('/api/v1/revenue')
def revenue():
  data = gb.get_revenue()
  return jsonify({'revenue': data})


def _db_path() -> str:
  return os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'product', 'data.sqlite'))

def _fetch_borrow_records(date: str | None) -> List[Dict[str, Any]]:
  conn = sqlite3.connect(_db_path())
  conn.row_factory = sqlite3.Row
  try:
    cur = conn.cursor()
    if date:
      cur.execute('SELECT * FROM records WHERE borrowDate = ? ORDER BY id DESC', (date,))
    else:
      cur.execute('SELECT * FROM records ORDER BY id DESC')
    records = [dict(r) for r in cur.fetchall()]
    items_stmt = conn.cursor()
    out = []
    for r in records:
      items_stmt.execute('SELECT * FROM items WHERE recordId = ? ORDER BY id ASC', (r['id'],))
      items = [dict(i) for i in items_stmt.fetchall()]
      out.append({**r, 'items': items})
    return out
  finally:
    conn.close()

@app.get('/api/v1/borrow/records')
def borrow_records():
  date = request.args.get('date')
  data = _fetch_borrow_records(date)
  return jsonify(data)

def _conn():
  p = _db_path()
  conn = sqlite3.connect(p)
  conn.row_factory = sqlite3.Row
  conn.execute('PRAGMA foreign_keys = ON')
  return conn

def _compute_status(items: List[Dict[str, Any]]) -> str:
  if not items:
    return 'pending'
  all_ret = all((int(i.get('returnedQuantity') or 0)) >= int(i.get('quantity') or 0) for i in items)
  any_ret = any(0 < int(i.get('returnedQuantity') or 0) < int(i.get('quantity') or 0) for i in items)
  if all_ret:
    return 'returned'
  if any_ret:
    return 'partial'
  return 'pending'

def _record_with_items(conn, rid: int) -> Dict[str, Any] | None:
  r = conn.execute('SELECT * FROM records WHERE id = ?', (rid,)).fetchone()
  if not r:
    return None
  items = conn.execute('SELECT * FROM items WHERE recordId = ? ORDER BY id ASC', (rid,)).fetchall()
  return {**dict(r), 'items': [dict(i) for i in items]}

@app.post('/api/v1/borrow/records')
def borrow_create():
  payload = request.json or {}
  borrower = payload.get('borrower')
  borrowDate = payload.get('borrowDate')
  borrowUnit = payload.get('borrowUnit')
  sourceUnit = payload.get('sourceUnit')
  sourcePerson = payload.get('sourcePerson')
  notes = payload.get('notes') or ''
  items = payload.get('items') or []
  if not borrower or not borrowDate or not borrowUnit or not sourceUnit or not sourcePerson:
    return jsonify({'error': '缺少必要字段'}), 400
  if not isinstance(items, list) or len(items) == 0:
    return jsonify({'error': '至少需要一件商品'}), 400
  conn = _conn()
  try:
    status = _compute_status(items)
    cur = conn.cursor()
    cur.execute(
      'INSERT INTO records (borrower, borrowDate, borrowUnit, sourceUnit, sourcePerson, notes, status) VALUES (?,?,?,?,?,?,?)',
      (borrower, borrowDate, borrowUnit, sourceUnit, sourcePerson, notes, status)
    )
    rid = cur.lastrowid
    ins = conn.cursor()
    for it in items:
      name = it.get('name')
      if not name:
        continue
      spec = it.get('spec') or ''
      qty = int(it.get('quantity') or 0)
      ret = int(it.get('returnedQuantity') or 0)
      ins.execute('INSERT INTO items (recordId, name, spec, quantity, returnedQuantity) VALUES (?,?,?,?,?)', (rid, name, spec, qty, ret))
    conn.commit()
    out = _record_with_items(conn, rid)
    return jsonify(out), 201
  except Exception as e:
    return jsonify({'error': str(e)}), 500
  finally:
    conn.close()

@app.delete('/api/v1/borrow/records/<int:rid>')
def borrow_delete(rid: int):
  conn = _conn()
  try:
    conn.execute('DELETE FROM items WHERE recordId = ?', (rid,))
    conn.execute('DELETE FROM records WHERE id = ?', (rid,))
    conn.commit()
    return jsonify({'ok': True})
  except Exception as e:
    return jsonify({'error': str(e)}), 500
  finally:
    conn.close()

@app.post('/api/v1/borrow/records/<int:rid>/return')
def borrow_return(rid: int):
  payload = request.json or {}
  returns = payload.get('returns') or []
  returnDate = payload.get('returnDate')
  returnNotes = payload.get('returnNotes') or ''
  if not isinstance(returns, list):
    return jsonify({'error': 'returns 必须为数组'}), 400
  conn = _conn()
  try:
    items = [dict(i) for i in conn.execute('SELECT * FROM items WHERE recordId = ?', (rid,)).fetchall()]
    for r in returns:
      itemId = int(r.get('itemId') or 0)
      qty = int(r.get('qty') or 0)
      it = next((i for i in items if int(i['id']) == itemId), None)
      if not it:
        continue
      remaining = max(0, int(it['quantity']) - int(it['returnedQuantity']))
      applyQty = min(remaining, max(0, qty))
      newReturned = int(it['returnedQuantity']) + applyQty
      conn.execute('UPDATE items SET returnedQuantity = ? WHERE id = ?', (newReturned, itemId))
    updated = [dict(i) for i in conn.execute('SELECT * FROM items WHERE recordId = ?', (rid,)).fetchall()]
    status = _compute_status(updated)
    conn.execute('UPDATE records SET status = ?, returnDate = ?, returnNotes = ? WHERE id = ?', (status, returnDate, returnNotes, rid))
    conn.commit()
    out = _record_with_items(conn, rid)
    return jsonify(out)
  except Exception as e:
    return jsonify({'error': str(e)}), 500
  finally:
    conn.close()

if __name__ == '__main__':
  app.run(host='0.0.0.0', port=8000)