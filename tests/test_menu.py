import os
from menu_system.services import init_db, import_markdown, compute_nutrition
from menu_system.db import engine, Base

def setup_module():
    Base.metadata.create_all(bind=engine)
    init_db()

def test_import_basic():
    md = """
# 意大利面 揭示用
## 番茄海鲜面
速冻菠菜段 2000g
大豆油 60g
牛排粉 24g
"""
    res = import_markdown(md)
    assert res["imported"] >= 1

def test_compute_nutrition_empty():
    assert isinstance(compute_nutrition(0), dict)
