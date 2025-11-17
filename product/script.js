// script.js
class BorrowingSystem {
  constructor() {
    this.records = [];
    this.currentReturnId = null;
    this.itemRowIdCounter = 0;
    this.init();
  }

  init() {
    this.bindEvents();
    this.loadInitialData().then(() => {
      this.renderRecords();
      this.updateStats();
      this.setDefaultDate();
      this.initializeItemsUI();
    });
  }

  bindEvents() {
    // 表单提交事件
    document.getElementById('borrowForm').addEventListener('submit', (e) => {
      e.preventDefault();
      this.addRecord();
    });

    // 搜索事件
    document.getElementById('searchInput').addEventListener('input', () => {
      this.filterRecords();
    });

    // 状态筛选事件
    document.getElementById('statusFilter').addEventListener('change', () => {
      this.filterRecords();
    });

    // 模态框事件
    document.querySelector('.close').addEventListener('click', () => {
      this.closeModal();
    });

    document.getElementById('cancelReturn').addEventListener('click', () => {
      this.closeModal();
    });

    document.getElementById('confirmReturn').addEventListener('click', () => {
      this.confirmReturn();
    });

    // 点击模态框外部关闭
    window.addEventListener('click', (e) => {
      const modal = document.getElementById('returnModal');
      if (e.target === modal) {
        this.closeModal();
      }
    });
  }

  async loadInitialData() {
    try {
      const res = await fetch('/api/records');
      if (res.ok) {
        const data = await res.json();
        this.records = Array.isArray(data) ? data : [];
        this.saveRecords();
        return;
      }
      const local = localStorage.getItem('borrowingRecords');
      this.records = local ? JSON.parse(local) : [];
    } catch (e) {
      console.warn('API不可用，使用本地缓存:', e);
      const local = localStorage.getItem('borrowingRecords');
      this.records = local ? JSON.parse(local) : [];
    }
  }

  async refreshFromServer() {
    try {
      const res = await fetch('/api/records');
      if (!res.ok) throw new Error('网络或权限问题');
      const data = await res.json();
      if (!data || !Array.isArray(data)) throw new Error('返回结构无效');
      this.records = data;
      this.saveRecords();
      this.renderRecords();
      this.updateStats();
      this.showNotification('已从后端刷新数据', 'success');
    } catch (e) {
      this.showNotification('刷新失败：' + e.message, 'error');
    }
  }

  initializeItemsUI() {
    const addItemBtn = document.getElementById('addItemBtn');
    const container = document.getElementById('itemsContainer');
    const addRow = (initialData = {}) => {
      const row = this.createItemRow(initialData);
      container.appendChild(row);
    };
    addItemBtn.addEventListener('click', () => addRow());
    // 初始添加一行
    addRow();
  }

  createItemRow(initialData = {}) {
    const row = document.createElement('div');
    row.className = 'item-row';
    row.dataset.rowId = ++this.itemRowIdCounter;

    const nameGroup = document.createElement('div');
    nameGroup.className = 'form-group';
    nameGroup.innerHTML = `
      <label>商品名称</label>
      <input type="text" class="item-name" placeholder="例如：螺丝刀" required>
    `;
    nameGroup.querySelector('input').value = initialData.name || '';

    const specGroup = document.createElement('div');
    specGroup.className = 'form-group';
    specGroup.innerHTML = `
      <label>规格</label>
      <input type="text" class="item-spec" placeholder="例如：十字 6mm">
    `;
    specGroup.querySelector('input').value = initialData.spec || '';

    const qtyGroup = document.createElement('div');
    qtyGroup.className = 'form-group';
    qtyGroup.innerHTML = `
      <label>数量</label>
      <input type="number" class="item-qty" min="1" placeholder="1" required>
    `;
    qtyGroup.querySelector('input').value = initialData.quantity || '';

    const removeBtn = document.createElement('button');
    removeBtn.type = 'button';
    removeBtn.className = 'btn btn-danger remove-item-btn';
    removeBtn.innerHTML = '<i class="fas fa-trash"></i>';
    removeBtn.addEventListener('click', () => {
      row.parentElement.removeChild(row);
    });

    row.appendChild(nameGroup);
    row.appendChild(specGroup);
    row.appendChild(qtyGroup);
    row.appendChild(removeBtn);
    return row;
  }

  getItemsFromForm() {
    const rows = Array.from(document.querySelectorAll('#itemsContainer .item-row'));
    const items = [];
    for (const r of rows) {
      const name = r.querySelector('.item-name').value.trim();
      const spec = r.querySelector('.item-spec').value.trim();
      const qtyStr = r.querySelector('.item-qty').value.trim();
      const quantity = parseInt(qtyStr, 10);
      if (!name || !quantity || quantity < 1) {
        continue;
      }
      items.push({ name, spec, quantity, returnedQuantity: 0 });
    }
    return items;
  }

  setDefaultDate() {
    const today = new Date().toISOString().split('T')[0];
    document.getElementById('borrowDate').value = today;
    const rd = document.getElementById('returnDate');
    if (rd) rd.value = today;
  }

  addRecord() {
    const formData = new FormData(document.getElementById('borrowForm'));
    const items = this.getItemsFromForm();
    if (items.length === 0) {
      alert('请至少添加一件商品且填写有效数量');
      return;
    }
    const payload = {
      borrower: formData.get('borrower'),
      items,
      borrowDate: formData.get('borrowDate'),
      borrowUnit: formData.get('borrowUnit'),
      sourceUnit: formData.get('sourceUnit'),
      sourcePerson: formData.get('sourcePerson'),
      notes: formData.get('notes') || ''
    };
    fetch('/api/records', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    }).then(async (res) => {
      if (!res.ok) throw new Error(await res.text());
      const created = await res.json();
      this.records.unshift(created);
      this.saveRecords();
      this.renderRecords();
      this.updateStats();
      this.resetForm();
      this.showNotification('借货记录添加成功！', 'success');
    }).catch(err => {
      alert('添加失败：' + err);
    });
  }

  deleteRecord(id) {
    if (confirm('确定要删除这条记录吗？')) {
      fetch(`/api/records/${id}`, { method: 'DELETE' })
        .then(async (res) => {
          if (!res.ok) throw new Error(await res.text());
          this.records = this.records.filter(record => record.id !== id);
          this.saveRecords();
          this.renderRecords();
          this.updateStats();
          this.showNotification('记录删除成功！', 'success');
        }).catch(err => alert('删除失败：' + err));
    }
  }

  openReturnModal(id) {
    this.currentReturnId = id;
    const record = this.records.find(r => r.id === id);
    if (record) {
      document.getElementById('returnModal').style.display = 'block';
      document.getElementById('returnDate').value = new Date().toISOString().split('T')[0];
      document.getElementById('returnNotes').value = '';
      // 渲染逐项归还行
      const container = document.getElementById('returnItemsContainer');
      container.innerHTML = '';
      record.items.forEach((item, idx) => {
        const remaining = Math.max(0, item.quantity - (item.returnedQuantity || 0));
        const row = document.createElement('div');
        row.className = 'return-item-row';
        row.dataset.index = idx;
        const summary = document.createElement('div');
        summary.className = 'return-item-summary';
        summary.textContent = `${item.name}${item.spec ? '（' + item.spec + '）' : ''} 借:${item.quantity} 已还:${item.returnedQuantity || 0} 剩:${remaining}`;
        const input = document.createElement('input');
        input.type = 'number';
        input.min = 0;
        input.max = remaining;
        input.placeholder = '归还数量';
        input.value = remaining > 0 ? remaining : 0;
        input.className = 'return-qty-input';
        const remainingTag = document.createElement('div');
        remainingTag.textContent = `可还：${remaining}`;
        const unitTag = document.createElement('div');
        unitTag.textContent = '数量';
        row.appendChild(summary);
        row.appendChild(unitTag);
        row.appendChild(remainingTag);
        row.appendChild(input);
        container.appendChild(row);
      });
    }
  }

  closeModal() {
    document.getElementById('returnModal').style.display = 'none';
    this.currentReturnId = null;
  }

  confirmReturn() {
    const returnDate = document.getElementById('returnDate').value;
    const returnNotes = document.getElementById('returnNotes').value;

    if (!returnDate) {
      alert('请选择还货日期');
      return;
    }

    const record = this.records.find(r => r.id === this.currentReturnId);
    if (record) {
      const rows = Array.from(document.querySelectorAll('#returnItemsContainer .return-item-row'));
      const returns = rows.map(row => {
        const idx = parseInt(row.dataset.index, 10);
        const input = row.querySelector('.return-qty-input');
        const qty = parseInt(input.value || '0', 10) || 0;
        const itemId = record.items[idx].id; // 使用数据库中的itemId
        return { itemId, qty };
      }).filter(r => r.qty > 0);
      if (returns.length === 0) {
        alert('请填写有效的归还数量');
        return;
      }
      fetch(`/api/records/${record.id}/return`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ returns, returnDate, returnNotes })
      }).then(async (res) => {
        if (!res.ok) throw new Error(await res.text());
        const updated = await res.json();
        const idx = this.records.findIndex(r => r.id === record.id);
        if (idx >= 0) this.records[idx] = updated;
        this.saveRecords();
        this.renderRecords();
        this.updateStats();
        this.closeModal();
        this.showNotification('还货操作成功！', 'success');
      }).catch(err => alert('还货失败：' + err));
    }
  }

  renderRecords() {
    const tbody = document.getElementById('recordsBody');
    const searchTerm = document.getElementById('searchInput').value.toLowerCase();
    const statusFilter = document.getElementById('statusFilter').value;

    let filteredRecords = this.records;

    // 搜索过滤
    if (searchTerm) {
      filteredRecords = filteredRecords.filter(record =>
        record.borrower.toLowerCase().includes(searchTerm) ||
        (record.items || []).some(it =>
          (it.name || '').toLowerCase().includes(searchTerm) ||
          (it.spec || '').toLowerCase().includes(searchTerm)
        ) ||
        record.borrowUnit.toLowerCase().includes(searchTerm) ||
        record.sourceUnit.toLowerCase().includes(searchTerm) ||
        record.sourcePerson.toLowerCase().includes(searchTerm)
      );
    }

    // 状态过滤
    if (statusFilter !== 'all') {
      filteredRecords = filteredRecords.filter(record => record.status === statusFilter);
    }

    if (filteredRecords.length === 0) {
      tbody.innerHTML = `
                <tr>
                    <td colspan="12" class="empty-state">
                        <i class="fas fa-inbox"></i>
                        <h3>暂无记录</h3>
                        <p>还没有符合条件的借货记录</p>
                    </td>
                </tr>
            `;
      return;
    }

    tbody.innerHTML = filteredRecords.map((record, index) => `
            <tr>
                <td>${index + 1}</td>
                <td>${record.borrower}</td>
                <td>${this.formatItemsCell(record.items)}</td>
                <td>${this.formatDate(record.borrowDate)}</td>
                <td>${record.borrowUnit}</td>
                <td>${record.sourceUnit}</td>
                <td>${record.sourcePerson}</td>
                <td>
                    <span class="status-badge status-${record.status}">
                        ${record.status === 'pending' ? '待还货' : (record.status === 'partial' ? '部分归还' : '已还货')}
                    </span>
                </td>
                <td>${record.returnDate ? this.formatDate(record.returnDate) : '-'}</td>
                <td title="${record.notes || record.returnNotes}">
                    ${this.truncateText(record.notes || record.returnNotes, 10)}
                </td>
                <td>
                    <div class="action-buttons">
                        ${record.status !== 'returned' ?
        `<button class="btn btn-success btn-sm" onclick="borrowingSystem.openReturnModal(${record.
          id})">
                                <i class="fas fa-undo"></i> 还货
                            </button>` : ''
      }
                        <button class="btn btn-danger btn-sm" onclick="borrowingSystem.deleteRecord(${record.id})">
                            <i class="fas fa-trash"></i> 删除
                        </button>
                    </div>
                </td>
            </tr>
        `).join('');
  }

  filterRecords() {
    this.renderRecords();
  }

  updateStats() {
    const total = this.records.length;
    const pending = this.records.filter(r => r.status === 'pending' || r.status === 'partial').length;
    const completed = this.records.filter(r => r.status === 'returned').length;

    document.getElementById('totalRecords').textContent = total;
    document.getElementById('pendingReturns').textContent = pending;
    document.getElementById('completedReturns').textContent = completed;
  }

  saveRecords() {
    localStorage.setItem('borrowingRecords', JSON.stringify(this.records));
  }

  // 导出数据为JSON文件，便于替换部署的 data.json，实现共享读取
  exportToJSON() {
    const payload = { records: this.records };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'data.json';
    link.click();
  }

  // 从选择的JSON文件导入，覆盖当前数据
  async importFromJSONFile(file) {
    try {
      const text = await file.text();
      const data = JSON.parse(text);
      if (!data || !Array.isArray(data.records)) {
        alert('JSON格式不正确：应包含records数组');
        return;
      }
      this.records = data.records;
      this.saveRecords();
      this.renderRecords();
      this.updateStats();
      this.showNotification('JSON导入成功！', 'success');
    } catch (e) {
      alert('导入失败：' + e.message);
    }
  }

  // 检测是否支持文件系统访问API
  isFileSystemAccessSupported() {
    return typeof window.showOpenFilePicker === 'function';
  }

  // 直接写入服务器同级目录的 data.json（需要在本机/localhost并由用户选取该文件）
  async saveToServerDataJson() {
    if (!this.isFileSystemAccessSupported()) {
      this.showNotification('浏览器不支持直接写入文件，已回退为下载', 'error');
      this.exportToJSON();
      return;
    }
    try {
      const [handle] = await window.showOpenFilePicker({
        multiple: false,
        types: [{ description: 'JSON 文件', accept: { 'application/json': ['.json'] } }]
      });
      if (!handle) return;
      const file = await handle.getFile();
      if (!file.name.toLowerCase().includes('data.json')) {
        const proceed = confirm(`已选择文件：${file.name}\n建议选择服务器目录下的 data.json。是否继续写入？`);
        if (!proceed) return;
      }
      const writable = await handle.createWritable();
      await writable.write(JSON.stringify({ records: this.records }, null, 2));
      await writable.close();
      this.showNotification('已写入服务器 data.json', 'success');
    } catch (e) {
      this.showNotification('写入失败：' + e.message, 'error');
    }
  }

  resetForm() {
    document.getElementById('borrowForm').reset();
    this.setDefaultDate();
    // 重置商品行，仅保留一条空行
    const container = document.getElementById('itemsContainer');
    container.innerHTML = '';
    container.appendChild(this.createItemRow());
  }

  formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('zh-CN');
  }

  truncateText(text, maxLength) {
    if (!text) return '-';
    return text.length > maxLength ? text.substring(0, maxLength) + '...' : text;
  }

  computeRecordStatus(record) {
    const items = record.items || [];
    if (items.length === 0) return 'pending';
    const allReturned = items.every(it => (it.returnedQuantity || 0) >= it.quantity);
    const anyReturned = items.some(it => (it.returnedQuantity || 0) > 0 && (it.returnedQuantity || 0) < it.quantity);
    if (allReturned) return 'returned';
    if (anyReturned) return 'partial';
    return 'pending';
  }

  formatItemsCell(items = []) {
    if (!items || items.length === 0) return '-';
    return items.map(it => {
      const returned = it.returnedQuantity || 0;
      const remaining = Math.max(0, it.quantity - returned);
      const spec = it.spec ? `（${it.spec}）` : '';
      return `${it.name}${spec} x${it.quantity}（已还${returned}，剩${remaining}）`;
    }).join('<br>');
  }

  showNotification(message, type) {
    // 创建通知元素
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.innerHTML = `
            <i class="fas ${type === 'success' ? 'fa-check-circle' : 'fa-exclamation-circle'}"></i>
            ${message}
        `;

    // 添加通知样式
    notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: ${type === 'success' ? '#48bb78' : '#f56565'};
            color: white;
            padding: 15px 20px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
            z-index: 1001;
            display: flex;
            align-items: center;
            gap: 10px;
            animation: slideInRight 0.3s ease;
        `;

    document.body.appendChild(notification);

    // 3秒后自动移除
    setTimeout(() => {
      notification.style.animation = 'slideOutRight 0.3s ease';
      setTimeout(() => {
        document.body.removeChild(notification);
      }, 300);
    }, 3000);
  }

  // 导出数据为CSV
  exportToCSV() {
    const headers = ['编号', '借货人', '商品明细', '借货日期', '借货单位', '源头单位', '源头负责人', '状态', '最近还货', '备注'];
    const csvContent = [
      headers.join(','),
      ...this.records.map((record, index) => [
        index + 1,
        record.borrower,
        (record.items || []).map(it => {
          const returned = it.returnedQuantity || 0;
          const remaining = Math.max(0, it.quantity - returned);
          const spec = it.spec ? `[${it.spec}]` : '';
          return `${it.name}${spec}x${it.quantity}|已还${returned}|剩${remaining}`;
        }).join('; '),
        record.borrowDate,
        record.borrowUnit,
        record.sourceUnit,
        record.sourcePerson,
        record.status === 'pending' ? '待还货' : (record.status === 'partial' ? '部分归还' : '已还货'),
        record.returnDate || '',
        (record.notes || record.returnNotes || '').replace(/,/g, '；')
      ].join(','))
    ].join('\n');

    const blob = new Blob(['\ufeff' + csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `借货统计_${new Date().toISOString().split('T')[0]}.csv`;
    link.click();
  }
}

// 添加导出按钮的CSS动画
const style = document.createElement('style');
style.textContent = `
    @keyframes slideInRight {
        from {
            transform: translateX(100%);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }
    
    @keyframes slideOutRight {
        from {
            transform: translateX(0);
opacity: 1;
        }
        to {
            transform: translateX(100%);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);

// 初始化系统
const borrowingSystem = new BorrowingSystem();

// 添加导出功能按钮（可选）
document.addEventListener('DOMContentLoaded', () => {
  const formSection = document.querySelector('.form-section');

  const btnRow = document.createElement('div');
  btnRow.style.display = 'flex';
  btnRow.style.gap = '10px';
  btnRow.style.marginTop = '10px';

  const exportCSVBtn = document.createElement('button');
  exportCSVBtn.className = 'btn btn-warning';
  exportCSVBtn.innerHTML = '<i class="fas fa-download"></i> 导出CSV';
  exportCSVBtn.onclick = () => borrowingSystem.exportToCSV();

  const exportJSONBtn = document.createElement('button');
  exportJSONBtn.className = 'btn btn-success';
  exportJSONBtn.innerHTML = '<i class="fas fa-file-export"></i> 导出JSON';
  exportJSONBtn.onclick = () => borrowingSystem.exportToJSON();

  const importJSONBtn = document.createElement('button');
  importJSONBtn.className = 'btn btn-secondary';
  importJSONBtn.innerHTML = '<i class="fas fa-file-import"></i> 导入JSON';

  const refreshBtn = document.createElement('button');
  refreshBtn.className = 'btn btn-primary';
  refreshBtn.innerHTML = '<i class="fas fa-rotate"></i> 刷新数据';
  refreshBtn.onclick = () => borrowingSystem.refreshFromServer();

  const saveServerBtn = document.createElement('button');
  saveServerBtn.className = 'btn btn-primary';
  saveServerBtn.innerHTML = '<i class="fas fa-floppy-disk"></i> 保存到服务器data.json';
  saveServerBtn.onclick = () => borrowingSystem.saveToServerDataJson();
  // 如果不支持文件系统访问API则隐藏该按钮
  if (!borrowingSystem.isFileSystemAccessSupported()) {
    saveServerBtn.style.display = 'none';
  }

  const fileInput = document.createElement('input');
  fileInput.type = 'file';
  fileInput.accept = 'application/json';
  fileInput.style.display = 'none';
  importJSONBtn.onclick = () => fileInput.click();
  fileInput.onchange = (e) => {
    const file = e.target.files && e.target.files[0];
    if (file) borrowingSystem.importFromJSONFile(file);
    fileInput.value = '';
  };

  btnRow.appendChild(exportCSVBtn);
  btnRow.appendChild(exportJSONBtn);
  btnRow.appendChild(importJSONBtn);
  btnRow.appendChild(refreshBtn);
  btnRow.appendChild(saveServerBtn);
  btnRow.appendChild(fileInput);
  formSection.appendChild(btnRow);
});
