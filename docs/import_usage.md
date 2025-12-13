# 数据导入工具

- 调用 POST /api/menu/import
- body: { "text": "Markdown全文" }
- 解析规则:
  - 一级标题作为分类
  - 二级标题作为菜品
  - 行内的原料、数量、单位按规范提取
