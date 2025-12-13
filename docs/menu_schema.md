# 菜单管理系统数据库Schema

## 实体

- cuisines(id, name)
- categories(id, name, cuisine_id)
- dishes(id, name, code, category_id)
- ingredients(id, name, default_unit)
- nutrition_profiles(id, ingredient_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g)
- recipe_versions(id, dish_id, version, created_at, active)
- recipe_items(id, recipe_version_id, ingredient_id, amount, unit)

## 约束

- category: (cuisine_id, name) 唯一
- dish: (category_id, name) 唯一
- recipe_version: (dish_id, version) 唯一
