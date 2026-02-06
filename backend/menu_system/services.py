import re
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from .db import SessionLocal, Base, engine
from .models import Cuisine, Category, Dish, Ingredient, RecipeVersion, RecipeItem, NutritionProfile
from datetime import datetime

def init_db():
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as s:
        if not s.execute(select(Cuisine).where(Cuisine.name == "默认")).scalars().first():
            s.add(Cuisine(name="默认"))
            s.commit()

def get_or_create_cuisine(name):
    with SessionLocal() as s:
        c = s.execute(select(Cuisine).where(Cuisine.name == name)).scalars().first()
        if c:
            return c
        c = Cuisine(name=name)
        s.add(c)
        s.commit()
        s.refresh(c)
        return c

def get_or_create_category(cuisine_id, name):
    name = name.strip()
    with SessionLocal() as s:
        cat = s.execute(select(Category).where(Category.cuisine_id == cuisine_id, Category.name == name)).scalars().first()
        if cat:
            return cat
        cat = Category(name=name, cuisine_id=cuisine_id)
        s.add(cat)
        s.commit()
        s.refresh(cat)
        return cat

def update_category(id, name=None, sort_order=None):
    with SessionLocal() as s:
        cat = s.get(Category, id)
        if not cat: return None
        if name is not None: cat.name = name.strip()
        if sort_order is not None: cat.sort_order = sort_order
        s.commit()
        s.refresh(cat)
        return cat

def delete_category(id):
    with SessionLocal() as s:
        cat = s.get(Category, id)
        if cat:
            s.delete(cat)
            s.commit()
            return True
        return False

def merge_categories(target_id, source_ids):
    with SessionLocal() as s:
        target = s.get(Category, target_id)
        if not target: return False
        
        for sid in source_ids:
            if sid == target_id: continue
            source = s.get(Category, sid)
            if not source: continue
            
            # Move dishes
            for dish in source.dishes:
                dish.category_id = target_id
            
            # Delete source category
            s.delete(source)
        s.commit()
        return True

def create_dish(category_id, name, code=None, price=0.0, description=None):
    with SessionLocal() as s:
        d = Dish(category_id=category_id, name=name.strip(), code=code, price=price, description=description)
        s.add(d)
        s.commit()
        s.refresh(d)
        return d

def update_dish(id, name=None, code=None, price=None, description=None, category_id=None):
    with SessionLocal() as s:
        d = s.get(Dish, id)
        if not d: return None
        if name is not None: d.name = name.strip()
        if code is not None: d.code = code
        if price is not None: d.price = price
        if description is not None: d.description = description
        if category_id is not None: d.category_id = category_id
        s.commit()
        s.refresh(d)
        return d

def delete_dish(id):
    with SessionLocal() as s:
        d = s.get(Dish, id)
        if d:
            s.delete(d)
            s.commit()
            return True
        return False


def get_or_create_ingredient(name, default_unit="g"):
    with SessionLocal() as s:
        ing = s.execute(select(Ingredient).where(Ingredient.name == name)).scalars().first()
        if ing:
            return ing
        ing = Ingredient(name=name.strip(), default_unit=default_unit)
        s.add(ing)
        s.commit()
        s.refresh(ing)
        return ing

def _get_or_create_ingredient_in_session(s, name, default_unit="g"):
    name = (name or "").strip()
    ing = s.execute(select(Ingredient).where(Ingredient.name == name)).scalars().first()
    if ing:
        return ing
    ing = Ingredient(name=name, default_unit=default_unit)
    s.add(ing)
    s.flush()
    return ing

def create_dish_with_version(category_id, dish_name, version="v1", items=None):
    with SessionLocal() as s:
        d = s.execute(select(Dish).where(Dish.category_id == category_id, Dish.name == dish_name)).scalars().first()
        if not d:
            d = Dish(name=dish_name, category_id=category_id)
            s.add(d)
            s.commit()
            s.refresh(d)
        existing = s.execute(select(RecipeVersion).where(RecipeVersion.dish_id == d.id, RecipeVersion.version == version)).scalars().first()
        rv = existing if existing else RecipeVersion(dish_id=d.id, version=version, active=True, created_at=datetime.utcnow())
        if not existing:
            s.add(rv)
            try:
                s.commit()
                s.refresh(rv)
            except IntegrityError:
                s.rollback()
                rv = s.execute(select(RecipeVersion).where(RecipeVersion.dish_id == d.id, RecipeVersion.version == version)).scalars().first()
        if items:
            olds = s.execute(select(RecipeItem).where(RecipeItem.recipe_version_id == rv.id)).scalars().all()
            for oi in olds:
                s.delete(oi)
            s.flush()
            to_add = []
            for idx, it in enumerate(items):
                ing = _get_or_create_ingredient_in_session(s, it.get("name"), it.get("unit") or "g")
                to_add.append(RecipeItem(
                    recipe_version_id=rv.id,
                    ingredient_id=ing.id,
                    amount=float(it.get("amount") or 0),
                    unit=it.get("unit") or "g",
                    order_index=idx,
                ))
            if to_add:
                s.add_all(to_add)
            s.commit()
        return rv

def compute_nutrition(recipe_version_id):
    with SessionLocal() as s:
        items = s.execute(select(RecipeItem).where(RecipeItem.recipe_version_id == recipe_version_id)).scalars().all()
        total = {"calories": 0.0, "protein": 0.0, "fat": 0.0, "carbs": 0.0}
        for it in items:
            np = s.execute(select(NutritionProfile).where(NutritionProfile.ingredient_id == it.ingredient_id)).scalars().first()
            if not np:
                continue
            grams = _to_grams(it.amount, it.unit)
            factor = grams / 100.0
            total["calories"] += np.calories_per_100g * factor
            total["protein"] += np.protein_per_100g * factor
            total["fat"] += np.fat_per_100g * factor
            total["carbs"] += np.carbs_per_100g * factor
        for k in total:
            total[k] = round(total[k], 2)
        return total

def _to_grams(amount, unit):
    if unit in ("g", "ml", "cc"):
        return float(amount)
    return float(amount)

def import_markdown(text, default_cuisine="默认"):
    lines = text.splitlines()
    current_section = None
    current_recipe = None
    body = []
    out = []
    
    def flush():
        nonlocal current_recipe, body, current_section
        if not current_recipe:
            return
        
        category_name = current_section
        if category_name and category_name.endswith(" 揭示用"):
             category_name = category_name.replace(" 揭示用", "").strip()
        
        ings = []
        unit_pattern = r'(?:g|ml|cc|L|kg|个|颗|片|根|袋|罐|只|段|下|圈|勺|满勺|平勺)'
        qty_in_token = re.compile(r'(\d+(?:\.\d+)?|\d+/\d+)\s*(' + unit_pattern + r')')

        for ln in body:
            raw = ln.strip()
            if not raw:
                continue
            # Remove leading bullets and circled numbers
            raw = re.sub(r'^[\s\u2022]+', '', raw)
            raw = re.sub(r'^[\u2460-\u2473]\s*', '', raw)
            # Remove parentheses content
            raw = re.sub(r"\([^\)]*\)", "", raw)
            tokens = raw.split()
            found = False
            for idx, tok in enumerate(tokens):
                m = qty_in_token.search(tok)
                if not m:
                    continue
                num_str = m.group(1).strip()
                unit = m.group(2).strip()
                try:
                    amount = float(num_str) if '/' not in num_str else _fraction(num_str)
                except Exception:
                    continue
                name_prefix = tok[:m.start()].strip()
                name_parts = []
                if idx > 0:
                    name_parts.append(" ".join(tokens[:idx]).strip())
                if name_prefix:
                    name_parts.append(name_prefix)
                name = " ".join([p for p in name_parts if p]).strip()
                if name:
                    ings.append({"name": name, "amount": amount, "unit": unit})
                    found = True
                break

        if current_recipe:
            out.append({"section": category_name, "name": current_recipe, "items": ings})
        current_recipe = None
        body = []

    for ln in lines:
        if ln.strip().startswith("# "):
            flush()
            current_section = ln.strip()[2:].strip()
        elif ln.strip().startswith("## "):
            flush()
            current_recipe = ln.strip()[3:].strip()
        else:
            if ln.strip():
                body.append(ln.strip())
    flush()
    
    cui = get_or_create_cuisine(default_cuisine)
    count = 0
    for rec in out:
        cat = get_or_create_category(cui.id, rec["section"]) if rec["section"] else get_or_create_category(cui.id, "默认分类")
        create_dish_with_version(cat.id, rec["name"], "v1", rec["items"])
        count += 1
    return {"imported": count, "recipes": out}

def _fraction(s):
    a, b = s.split("/")
    return float(a) / float(b)

def upsert_nutrition(ingredient_name, calories, protein, fat, carbs):
    with SessionLocal() as s:
        ing = s.execute(select(Ingredient).where(Ingredient.name == ingredient_name)).scalars().first()
        if not ing:
            ing = Ingredient(name=ingredient_name, default_unit="g")
            s.add(ing)
            s.commit()
            s.refresh(ing)
        np = s.execute(select(NutritionProfile).where(NutritionProfile.ingredient_id == ing.id)).scalars().first()
        if not np:
            np = NutritionProfile(ingredient_id= ing.id)
            s.add(np)
        np.calories_per_100g = float(calories or 0)
        np.protein_per_100g = float(protein or 0)
        np.fat_per_100g = float(fat or 0)
        np.carbs_per_100g = float(carbs or 0)
        s.commit()
        return {"ok": True}


# Voice Reminder Services
def get_voice_reminders():
    """获取所有语音提醒"""
    from .models import VoiceReminder
    with SessionLocal() as s:
        return s.query(VoiceReminder).all()

def create_voice_reminder(time, content, reminder_type='ai_voice', voice_model='tts-1', audio_file_path=None):
    """创建语音提醒"""
    from .models import VoiceReminder
    with SessionLocal() as s:
        reminder = VoiceReminder(
            time=time,
            content=content,
            enabled=True,
            reminder_type=reminder_type,
            voice_model=voice_model,
            audio_file_path=audio_file_path
        )
        s.add(reminder)
        s.commit()
        s.refresh(reminder)
        return reminder

def batch_create_voice_reminders(items):
    """批量创建语音提醒"""
    from .models import VoiceReminder
    with SessionLocal() as s:
        reminders = []
        for item in items:
            reminder = VoiceReminder(
                time=item.get('time'),
                content=item.get('content'),
                enabled=True,
                reminder_type=item.get('reminder_type', 'ai_voice'),
                voice_model=item.get('voice_model', 'tts-1'),
                audio_file_path=item.get('audio_file_path')
            )
            s.add(reminder)
            reminders.append(reminder)
        s.commit()
        for r in reminders:
            s.refresh(r)
        return reminders

def update_voice_reminder(rid, time=None, content=None, enabled=None, 
                         reminder_type=None, voice_model=None, audio_file_path=None):
    """更新语音提醒"""
    from .models import VoiceReminder
    with SessionLocal() as s:
        reminder = s.get(VoiceReminder, rid)
        if not reminder:
            return None
        
        if time is not None:
            reminder.time = time
        if content is not None:
            reminder.content = content
        if enabled is not None:
            reminder.enabled = enabled
        if reminder_type is not None:
            reminder.reminder_type = reminder_type
        if voice_model is not None:
            reminder.voice_model = voice_model
        if audio_file_path is not None:
            reminder.audio_file_path = audio_file_path
        
        s.commit()
        s.refresh(reminder)
        return reminder

def delete_voice_reminder(rid):
    """删除语音提醒"""
    from .models import VoiceReminder
    with SessionLocal() as s:
        reminder = s.get(VoiceReminder, rid)
        if reminder:
            s.delete(reminder)
            s.commit()
            return True
        return False

def delete_all_voice_reminders():
    """删除所有语音提醒"""
    from .models import VoiceReminder
    with SessionLocal() as s:
        s.query(VoiceReminder).delete()
        s.commit()

def add_push_subscription(endpoint, p256dh, auth):
    """添加推送订阅"""
    from .models import PushSubscription
    with SessionLocal() as s:
        # 检查是否已存在
        existing = s.query(PushSubscription).filter_by(endpoint=endpoint).first()
        if existing:
            # 更新密钥
            existing.p256dh_key = p256dh
            existing.auth_key = auth
        else:
            # 创建新订阅
            subscription = PushSubscription(
                endpoint=endpoint,
                p256dh_key=p256dh,
                auth_key=auth
            )
            s.add(subscription)
        s.commit()

def delete_push_subscription(endpoint):
    """删除推送订阅"""
    from .models import PushSubscription
    with SessionLocal() as s:
        subscription = s.query(PushSubscription).filter_by(endpoint=endpoint).first()
        if subscription:
            s.delete(subscription)
            s.commit()
            return True
        return False
