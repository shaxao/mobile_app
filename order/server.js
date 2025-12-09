const express = require('express');
const cors = require('cors');
const fs = require('fs').promises;
const path = require('path');

const app = express();
const PORT = 3001;
const DATA_DIR = path.join(__dirname, 'data');

// 中间件
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  res.header('Access-Control-Allow-Credentials', 'true');

  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});
app.use(express.json({ limit: '50mb' })); // 增加请求体大小限制

// 确保数据目录存在
async function ensureDataDir() {
  try {
    await fs.access(DATA_DIR);
  } catch {
    await fs.mkdir(DATA_DIR, { recursive: true });
  }
}

// 获取用户数据文件路径
function getUserDataPath(userId) {
  return path.join(DATA_DIR, `${userId}.json`);
}

// 读取用户数据
async function readUserData(userId) {
  try {
    const filePath = getUserDataPath(userId);
    const data = await fs.readFile(filePath, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    return {};
  }
}

// 写入用户数据
async function writeUserData(userId, data) {
  try {
    const filePath = getUserDataPath(userId);
    await fs.writeFile(filePath, JSON.stringify(data, null, 2));
    return true;
  } catch (error) {
    console.error('写入用户数据失败:', error);
    return false;
  }
}

// API路由前缀
const apiRouter = express.Router();

// 保存数据接口
apiRouter.post('/save', async (req, res) => {
  try {
    const { userId, key, data } = req.body;

    if (!userId || !key || data === undefined) {
      return res.status(400).json({
        success: false,
        error: '缺少必要参数'
      });
    }

    const userData = await readUserData(userId);
    userData[key] = data;
    userData.lastModified = new Date().toISOString();

    const success = await writeUserData(userId, userData);

    res.json({
      success,
      message: success ? '保存成功' : '保存失败'
    });
  } catch (error) {
    console.error('保存数据错误:', error);
    res.status(500).json({
      success: false,
      error: '服务器内部错误'
    });
  }
});

// 加载数据接口
apiRouter.get('/load/:userId/:key', async (req, res) => {
  try {
    const { userId, key } = req.params;

    const userData = await readUserData(userId);
    const data = userData[key] || null;

    res.json({
      success: true,
      data,
      lastModified: userData.lastModified
    });
  } catch (error) {
    console.error('加载数据错误:', error);
    res.status(500).json({
      success: false,
      error: '服务器内部错误'
    });
  }
});

// 获取历史记录接口
apiRouter.get('/history/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const userData = await readUserData(userId);
    const historyData = {};

    // 筛选出历史记录数据
    for (const [key, value] of Object.entries(userData)) {
      if (key.startsWith('history_')) {
        historyData[key] = value;
      }
    }

    res.json({
      success: true,
      data: historyData
    });
  } catch (error) {
    console.error('获取历史记录错误:', error);
    res.status(500).json({
      success: false,
      error: '服务器内部错误'
    });
  }
});

// 健康检查接口
apiRouter.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    message: '本地数据同步服务运行正常'
  });
});

// 服务器状态接口
apiRouter.get('/status', (req, res) => {
  res.json({
    server: 'Local Data Sync Server',
    version: '1.0.0',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// 使用API路由
app.use('/api', apiRouter);

// 启动服务器
async function startServer() {
  await ensureDataDir();

  app.listen(PORT, () => {
    console.log(`本地数据同步服务器启动成功！`);
    console.log(`服务地址: http://localhost:${PORT}`);
    console.log(`健康检查: http://localhost:${PORT}/api/health`);
    console.log(`数据目录: ${DATA_DIR}`);
  });
}

startServer().catch(console.error);