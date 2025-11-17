import { useEffect, useMemo, useState } from 'react'
import './index.css'
import { Button } from './components/ui/button'
import { Input } from './components/ui/input'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from './components/ui/dialog'

type Item = { id?: number; name: string; specification?: string; quantity: number; returnedQuantity?: number }
type RecordRow = {
  id: number
  borrower: string
  borrowDate: string
  borrowUnit?: string
  sourceUnit?: string
  sourcePerson?: string
  notes?: string
  status: 'pending' | 'partial' | 'returned'
  returnDate?: string | null
  returnNotes?: string
  items: Item[]
}

function App() {
  const [records, setRecords] = useState<RecordRow[]>([])
  const [loading, setLoading] = useState(false)

  // Form state
  const [borrower, setBorrower] = useState('')
  const [borrowDate, setBorrowDate] = useState<string>(() => new Date().toISOString().slice(0, 10))
  const [itemName, setItemName] = useState('')
  const [itemQty, setItemQty] = useState<number>(1)
  const [formItems, setFormItems] = useState<Item[]>([])

  // Return dialog
  const [openReturn, setOpenReturn] = useState(false)
  const [returnForId, setReturnForId] = useState<number | null>(null)
  const recordToReturn = useMemo(() => records.find(r => r.id === returnForId) || null, [records, returnForId])
  const [returnDate, setReturnDate] = useState<string>(() => new Date().toISOString().slice(0, 10))
  const [returnNotes, setReturnNotes] = useState<string>('')
  const [returnQty, setReturnQty] = useState<Record<number, number>>({})

  useEffect(() => {
    setLoading(true)
    fetch('http://127.0.0.1:3000/api/records')
      .then(async res => {
        const data = await res.json()
        setRecords(Array.isArray(data) ? data : [])
      })
      .finally(() => setLoading(false))
  }, [])

  const addItemToForm = () => {
    if (!itemName.trim() || itemQty <= 0) return
    setFormItems(prev => [...prev, { name: itemName.trim(), quantity: itemQty }])
    setItemName('')
    setItemQty(1)
  }

  const submitRecord = () => {
    if (!borrower.trim() || formItems.length === 0) return alert('请填写借用人并添加至少一件商品')
    const payload = { borrower, borrowDate, items: formItems }
    fetch('http://127.0.0.1:3000/api/records', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload)
    }).then(async res => {
      const created = await res.json()
      setRecords(prev => [created, ...prev])
      setBorrower('')
      setBorrowDate(new Date().toISOString().slice(0, 10))
      setFormItems([])
    }).catch(err => alert('添加失败：' + err))
  }

  const deleteRecord = (id: number) => {
    if (!confirm('确定删除该记录？')) return
    fetch(`http://127.0.0.1:3000/api/records/${id}`, { method: 'DELETE' })
      .then(() => setRecords(prev => prev.filter(r => r.id !== id)))
      .catch(err => alert('删除失败：' + err))
  }

  const openReturnDialog = (id: number) => {
    setReturnForId(id)
    setReturnDate(new Date().toISOString().slice(0, 10))
    setReturnNotes('')
    setReturnQty({})
    setOpenReturn(true)
  }

  const submitReturn = () => {
    if (!recordToReturn) return
    const returns = recordToReturn.items.map((it) => ({ itemId: it.id!, qty: returnQty[it.id!] || 0 })).filter(r => r.qty > 0)
    if (returns.length === 0) return alert('请填写有效归还数量')
    fetch(`http://127.0.0.1:3000/api/records/${recordToReturn.id}/return`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ returns, returnDate, returnNotes })
    }).then(async res => {
      const updated = await res.json()
      setRecords(prev => prev.map(r => r.id === updated.id ? updated : r))
      setOpenReturn(false)
    }).catch(err => alert('还货失败：' + err))
  }

  return (
    <div className="container py-6">
      <h1 className="text-2xl font-semibold mb-4">借货管理（shadcn/ui）</h1>

      <div className="grid md:grid-cols-3 gap-4 mb-6">
        <div className="md:col-span-1 space-y-2">
          <label className="text-sm">借用人</label>
          <Input value={borrower} onChange={e => setBorrower(e.target.value)} placeholder="姓名" />
          <label className="text-sm">借用日期</label>
          <Input type="date" value={borrowDate} onChange={e => setBorrowDate(e.target.value)} />

          <div className="mt-4 border rounded-md p-3">
            <div className="font-medium mb-2">商品</div>
            <div className="flex gap-2">
              <Input value={itemName} onChange={e => setItemName(e.target.value)} placeholder="商品名称" />
              <Input type="number" min={1} value={itemQty} onChange={e => setItemQty(parseInt(e.target.value || '1'))} />
              <Button onClick={addItemToForm}>添加</Button>
            </div>
            <ul className="mt-2 text-sm list-disc pl-5 space-y-1">
              {formItems.map((it, idx) => (
                <li key={idx}>{it.name} × {it.quantity}</li>
              ))}
            </ul>
          </div>

          <Button className="mt-4" onClick={submitRecord}>提交借货</Button>
        </div>

        <div className="md:col-span-2">
          <div className="flex items-center justify-between mb-2">
            <div className="text-sm text-muted-foreground">{loading ? '加载中…' : `记录数：${records.length}`}</div>
            <Button variant="secondary" onClick={() => {
              setLoading(true)
              fetch('http://127.0.0.1:3000/api/records')
                .then(async res => setRecords(await res.json()))
                .finally(() => setLoading(false))
            }}>刷新</Button>
          </div>
          <div className="overflow-x-auto border rounded-md">
            <table className="min-w-full text-sm">
              <thead className="bg-muted">
                <tr>
                  <th className="p-2 text-left">ID</th>
                  <th className="p-2 text-left">借用人</th>
                  <th className="p-2 text-left">状态</th>
                  <th className="p-2 text-left">日期</th>
                  <th className="p-2 text-left">操作</th>
                </tr>
              </thead>
              <tbody>
                {records.map(r => (
                  <tr key={r.id} className="border-t">
                    <td className="p-2">{r.id}</td>
                    <td className="p-2">{r.borrower}</td>
                    <td className="p-2">{r.status}</td>
                    <td className="p-2">{r.borrowDate}</td>
                    <td className="p-2 flex gap-2">
                      <Button size="sm" onClick={() => openReturnDialog(r.id)}>还货</Button>
                      <Button size="sm" variant="destructive" onClick={() => deleteRecord(r.id)}>删除</Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <Dialog open={openReturn} onOpenChange={setOpenReturn}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>还货</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <div>
              <label className="text-sm">还货日期</label>
              <Input type="date" value={returnDate} onChange={e => setReturnDate(e.target.value)} />
            </div>
            <div>
              <label className="text-sm">备注</label>
              <Input value={returnNotes} onChange={e => setReturnNotes(e.target.value)} />
            </div>
            <div className="space-y-2">
              {recordToReturn?.items.map((it) => (
                <div key={it.id} className="flex items-center gap-2">
                  <div className="flex-1">{it.name}（借出{it.quantity}，已还{it.returnedQuantity || 0}）</div>
                  <Input type="number" min={0} placeholder="归还数量" value={returnQty[it.id!]?.toString() || ''}
                    onChange={e => setReturnQty(prev => ({ ...prev, [it.id!]: parseInt(e.target.value || '0') }))} />
                </div>
              ))}
            </div>
          </div>
          <DialogFooter>
            <Button onClick={() => setOpenReturn(false)} variant="secondary">取消</Button>
            <Button onClick={submitReturn}>提交</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}

export default App
