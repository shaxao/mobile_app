import sys, os
sys.path.append(os.getcwd())
from backend.menu_system.services import init_db, import_markdown
from backend.menu_system.db import SessionLocal
from backend.menu_system.models import Dish, RecipeVersion, RecipeItem, Category
from sqlalchemy import select

def main():
    init_db()
    path = r'd:\\flutterResource\\01\\saliya\\萨莉亚菜单.md'
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    res = import_markdown(text, default_cuisine='菜单')
    print('Imported:', res)

    with SessionLocal() as s:
        names = [
            '熏香培根匹萨',
            '肉酱薄脆匹萨',
            '榴莲匹萨',
            '那不勒斯烩海鲜',
        ]
        for nm in names:
            d = s.execute(select(Dish).where(Dish.name==nm)).scalars().first()
            if not d:
                print('Missing dish:', nm)
                continue
            rv = d.versions[0]
            items = s.execute(select(RecipeItem).where(RecipeItem.recipe_version_id==rv.id)).scalars().all()
            print('Dish:', d.name, 'item_count:', len(items))
            for it in items:
                print('-', it.ingredient.name, it.amount, it.unit)

    # Debug raw parsing for 榴莲匹萨
    import re
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.read().splitlines()
    start = None
    for i, ln in enumerate(lines):
        if ln.strip() == '## 榴莲匹萨':
            start = i + 1
            break
    if start is not None:
        print('\nRaw lines under 榴莲匹萨:')
        unit_pattern = r'(?:g|ml|cc|L|kg|个|根|片|袋|罐|只|下|圈|cm|满勺|平勺)'
        qty_pattern = re.compile(r'^(\d+(?:\.\d+)?|[\d/]+)\s*(' + unit_pattern + r')')
        for ln in lines[start:]:
            if ln.strip().startswith('## ') or ln.strip().startswith('# '):
                break
            raw = ln.strip()
            if not raw:
                continue
            tmp = raw
            for char in " \t\u2022\u00b7*①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳":
                tmp = tmp.replace(char, ' ')
            tmp = tmp.strip()
            parts = tmp.split()
            found = False
            name = ''
            amt = ''
            unit = ''
            idx = -1
            token = ''
            for i, p in enumerate(parts):
                m = qty_pattern.search(p)
                if m:
                    idx = i
                    token = p
                    name = (' '.join(parts[:i]) + ' ' + p[:m.start()]).strip()
                    amt = m.group(1)
                    unit = m.group(2)
                    found = True
                    break
            print(f"LINE: {raw}")
            if found:
                print(f"  -> NAME='{name}' AMT='{amt}' UNIT='{unit}' token='{token}' parts={parts}")
            else:
                print("  -> NO MATCH")

if __name__ == '__main__':
    main()
    # Isolate test for 榴莲匹萨
    from backend.menu_system.db import SessionLocal
    from sqlalchemy import delete
    with SessionLocal() as s:
        d = s.execute(select(Dish).where(Dish.name=='榴莲匹萨')).scalars().first()
        if d:
            for v in d.versions:
                s.execute(delete(RecipeItem).where(RecipeItem.recipe_version_id==v.id))
            s.commit()
    md_small = """
# 匹萨 揭示用
## 榴莲匹萨
• ①9寸实验饼底 1个
• ②榴莲酱 60g（正餐更2满勺）
• ③秒可蓝多马苏里拉奶酪 50g
"""
    res2 = import_markdown(md_small, default_cuisine='菜单')
    print('Small import:', res2)
    with SessionLocal() as s:
        d = s.execute(select(Dish).where(Dish.name=='榴莲匹萨')).scalars().first()
        if d:
            rv = d.versions[0]
            items = s.execute(select(RecipeItem).where(RecipeItem.recipe_version_id==rv.id)).scalars().all()
            print('After small import item_count:', len(items))
            for it in items:
                print('-', it.ingredient.name, it.amount, it.unit)
