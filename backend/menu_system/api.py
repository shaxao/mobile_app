from flask import Blueprint, jsonify, request
from sqlalchemy import select, func
from .db import SessionLocal
from .models import Cuisine, Category, Dish, RecipeVersion, RecipeItem, Ingredient, IngredientChangeLog, OperationLog
from .services import init_db, import_markdown, compute_nutrition
from .services import _get_or_create_ingredient_in_session
from .services import upsert_nutrition, create_dish, update_dish, delete_dish, update_category, delete_category, merge_categories

bp = Blueprint("menu", __name__, url_prefix="/api/menu")

@bp.route("/init", methods=["POST"])
def init():
    init_db()
    return jsonify({"ok": True})

@bp.route("/cuisines", methods=["GET"])
def cuisines():
    with SessionLocal() as s:
        rows = s.execute(select(Cuisine)).scalars().all()
        data = [{"id": r.id, "name": r.name} for r in rows]
        return jsonify({"data": data})

@bp.route("/tree", methods=["GET"])
def tree():
    with SessionLocal() as s:
        out = []
        for cu in s.execute(select(Cuisine)).scalars().all():
            node = {"id": cu.id, "name": cu.name, "categories": []}
            cats = sorted(cu.categories, key=lambda x: x.sort_order or 0)
            for cat in cats:
                cnode = {"id": cat.id, "name": cat.name, "sort_order": cat.sort_order, "dishes": []}
                for d in cat.dishes:
                    dnode = {
                        "id": d.id, "name": d.name, "code": d.code,
                        "price": d.price, "description": d.description,
                        "versions": []
                    }
                    for v in d.versions:
                        vnode = {"id": v.id, "version": v.version, "active": v.active}
                        dnode["versions"].append(vnode)
                    cnode["dishes"].append(dnode)
                node["categories"].append(cnode)
            out.append(node)
        return jsonify({"data": out})

@bp.route("/categories/<int:id>", methods=["PUT"])
def update_cat(id):
    body = request.json or {}
    cat = update_category(id, name=body.get("name"), sort_order=body.get("sort_order"))
    if not cat: return jsonify({"error": "not found"}), 404
    return jsonify({"ok": True})

@bp.route("/categories/<int:id>", methods=["DELETE"])
def delete_cat(id):
    ok = delete_category(id)
    if not ok: return jsonify({"error": "not found"}), 404
    return jsonify({"ok": True})

@bp.route("/categories/merge", methods=["POST"])
def merge_cat():
    body = request.json or {}
    target = body.get("target_id")
    sources = body.get("source_ids")
    if not target or not sources:
        return jsonify({"error": "missing target_id or source_ids"}), 400
    ok = merge_categories(target, sources)
    if not ok: return jsonify({"error": "failed"}), 400
    return jsonify({"ok": True})

@bp.route("/dishes", methods=["POST"])
def create_d():
    body = request.json or {}
    d = create_dish(
        body.get("category_id"), 
        body.get("name"), 
        code=body.get("code"), 
        price=body.get("price"), 
        description=body.get("description")
    )
    return jsonify({"id": d.id})

@bp.route("/dishes/<int:id>", methods=["PUT"])
def update_d(id):
    body = request.json or {}
    d = update_dish(
        id, 
        name=body.get("name"), 
        code=body.get("code"), 
        price=body.get("price"), 
        description=body.get("description"),
        category_id=body.get("category_id")
    )
    if not d: return jsonify({"error": "not found"}), 404
    return jsonify({"ok": True})

@bp.route("/dishes/<int:id>", methods=["DELETE"])
def delete_d(id):
    ok = delete_dish(id)
    if not ok: return jsonify({"error": "not found"}), 404
    return jsonify({"ok": True})

@bp.route("/import", methods=["POST"])
def import_md():
    text = request.json.get("text") or ""
    res = import_markdown(text)
    return jsonify(res)

@bp.route("/import-file", methods=["POST"])
def import_file():
    body = request.json or {}
    path = body.get("path") or request.args.get("path") or ""
    cuisine = body.get("cuisine") or request.args.get("cuisine") or "默认"
    if not path:
        return jsonify({"error": "缺少 path"}), 400
    try:
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
    except Exception as e:
        return jsonify({"error": str(e), "path": path}), 500
    res = import_markdown(text, default_cuisine=cuisine)
    return jsonify({**res, "path": path, "cuisine": cuisine})

@bp.route("/import-upload", methods=["POST"])
def import_upload():
    cuisine = (request.form.get("cuisine") or request.args.get("cuisine") or "默认").strip()
    f = request.files.get("file")
    if not f:
        return jsonify({"error": "缺少文件"}), 400
    name = f.filename or "import.md"
    try:
        b = f.read()
        text = b.decode("utf-8", errors="ignore")
        res = import_markdown(text, default_cuisine=cuisine)
        return jsonify({**res, "filename": name, "size": len(b), "cuisine": cuisine})
    except Exception as e:
        return jsonify({"error": str(e), "filename": name}), 500

@bp.route("/recipes/<int:version_id>/items", methods=["GET"])
def recipe_items(version_id):
    with SessionLocal() as s:
        rv = s.execute(select(RecipeVersion).where(RecipeVersion.id == version_id)).scalars().first()
        if not rv:
            return jsonify({"error": "not found"}), 404
        
        rows = sorted(rv.items, key=lambda x: x.order_index or 0)
        items = []
        for ri in rows:
            # Check if this ingredient is also a dish (for hierarchy)
            linked_dish = s.execute(select(Dish).where(Dish.name == ri.ingredient.name)).scalars().first()
            linked_version_id = None
            if linked_dish and linked_dish.versions:
                active_v = next((v for v in linked_dish.versions if v.active), linked_dish.versions[0])
                linked_version_id = active_v.id

            items.append({
                "id": ri.id,
                "ingredient_name": ri.ingredient.name,
                "amount": ri.amount,
                "unit": ri.unit,
                "linked_dish_id": linked_dish.id if linked_dish else None,
                "linked_version_id": linked_version_id
            })
        return jsonify({"data": items})

@bp.route("/recipes/<int:version_id>/nutrition", methods=["GET"])
def recipe_nutrition(version_id):
    res = compute_nutrition(version_id)
    return jsonify(res)

@bp.route("/nutrition", methods=["POST"])
def nutrition_upsert():
    body = request.json or {}
    name = body.get("name")
    res = upsert_nutrition(
        name,
        body.get("calories_per_100g"),
        body.get("protein_per_100g"),
        body.get("fat_per_100g"),
        body.get("carbs_per_100g"),
    )
    return jsonify(res)

@bp.route("/nutrition/batch", methods=["POST"])
def nutrition_batch():
    items = request.json.get("items") or []
    out = []
    for it in items:
        out.append(upsert_nutrition(
            it.get("name"),
            it.get("calories_per_100g"),
            it.get("protein_per_100g"),
            it.get("fat_per_100g"),
            it.get("carbs_per_100g"),
        ))
    return jsonify({"ok": True, "count": len(out)})

# --- Ingredient CRUD ---

def _require_role(role_needed):
    role = (request.args.get("role") or request.headers.get("X-Role") or "").strip().lower()
    if role_needed == "admin":
        return role == "admin"
    if role_needed == "editor":
        return role in ("editor", "admin")
    return True

@bp.route("/ingredients", methods=["GET"])
def ingredients_list():
    name = (request.args.get("name") or "").strip()
    itype = (request.args.get("type") or "").strip()
    with SessionLocal() as s:
        q = s.query(Ingredient)
        if name:
            q = q.filter(Ingredient.name.contains(name))
        if itype:
            q = q.filter(Ingredient.type == itype)
        rows = q.order_by(Ingredient.name.asc()).all()
        data = [{
            "id": r.id, "name": r.name, "type": r.type, "stock": r.stock,
            "default_unit": r.default_unit,
            "updated_at": (r.updated_at.isoformat() if r.updated_at else None)
        } for r in rows]
        resp = jsonify({"data": data})
        resp.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        return resp

@bp.route("/ingredients", methods=["POST"])
def ingredients_create():
    body = request.json or {}
    name = (body.get("name") or "").strip()
    if not name:
        return jsonify({"error": "name required"}), 400
    if len(name) > 256:
        return jsonify({"error": "name too long"}), 400
    if any(ch in name for ch in "<>"):
        return jsonify({"error": "invalid chars"}), 400
    with SessionLocal() as s:
        exists = s.execute(select(Ingredient).where(Ingredient.name == name)).scalars().first()
        if exists:
            return jsonify({"error": "name exists"}), 400
        it = Ingredient(
            name=name,
            type=(body.get("type") or "").strip() or None,
            stock=float(body.get("stock") or 0),
            default_unit=(body.get("default_unit") or "g").strip() or "g",
        )
        s.add(it)
        s.commit()
        s.refresh(it)
        s.add(OperationLog(action="create", entity_type="ingredient", entity_id=it.id, detail=f"create {it.name}"))
        s.commit()
        data = {
            "id": it.id, "name": it.name, "type": it.type, "stock": it.stock,
            "default_unit": it.default_unit,
            "updated_at": (it.updated_at.isoformat() if it.updated_at else None)
        }
        resp = jsonify({"id": it.id, "data": data})
        resp.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        return resp

@bp.route("/ingredients/<int:id>", methods=["PUT"])
def ingredients_update(id):
    if not _require_role("editor"):
        return jsonify({"error": "forbidden"}), 403
    body = request.json or {}
    with SessionLocal() as s:
        it = s.get(Ingredient, id)
        if not it:
            return jsonify({"error": "not found"}), 404
        changes = []
        if "name" in body:
            new_name = (body.get("name") or "").strip()
            if not new_name:
                return jsonify({"error": "name required"}), 400
            if len(new_name) > 256:
                return jsonify({"error": "name too long"}), 400
            if any(ch in new_name for ch in "<>"):
                return jsonify({"error": "invalid chars"}), 400
            if new_name != it.name:
                exists = s.execute(select(Ingredient).where(Ingredient.name == new_name, Ingredient.id != id)).scalars().first()
                if exists:
                    return jsonify({"error": "name exists"}), 400
                changes.append(("name", it.name, new_name))
                it.name = new_name
        if "type" in body:
            new_type = (body.get("type") or "").strip() or None
            if new_type != it.type:
                changes.append(("type", it.type, new_type))
                it.type = new_type
        if "stock" in body:
            try:
                new_stock = float(body.get("stock"))
            except Exception:
                return jsonify({"error": "stock must be number"}), 400
            if new_stock != it.stock:
                changes.append(("stock", it.stock, new_stock))
                it.stock = new_stock
        if "default_unit" in body:
            new_unit = (body.get("default_unit") or "g").strip() or "g"
            if new_unit != it.default_unit:
                changes.append(("default_unit", it.default_unit, new_unit))
                it.default_unit = new_unit
        s.commit()
        for f, o, n in changes:
            s.add(IngredientChangeLog(ingredient_id=id, field_name=f, old_value=str(o) if o is not None else None, new_value=str(n) if n is not None else None))
        if changes:
            s.add(OperationLog(action="update", entity_type="ingredient", entity_id=id, detail=f"update {','.join([c[0] for c in changes])}"))
        s.commit()
        s.refresh(it)
        data = {
            "id": it.id, "name": it.name, "type": it.type, "stock": it.stock,
            "default_unit": it.default_unit,
            "updated_at": (it.updated_at.isoformat() if it.updated_at else None)
        }
        resp = jsonify({"ok": True, "changes": len(changes), "data": data})
        resp.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        return resp

@bp.route("/ingredients", methods=["DELETE"])
def ingredients_delete():
    if not _require_role("admin"):
        return jsonify({"error": "admin required"}), 403
    ids = request.json.get("ids") or []
    if not isinstance(ids, list) or not ids:
        return jsonify({"error": "ids required"}), 400
    with SessionLocal() as s:
        deleted = []
        blocked = []
        for iid in ids:
            cnt = s.query(func.count(RecipeItem.id)).filter(RecipeItem.ingredient_id == iid).scalar()
            if cnt and cnt > 0:
                blocked.append(iid)
                continue
            it = s.get(Ingredient, iid)
            if not it:
                continue
            s.delete(it)
            deleted.append(iid)
        s.commit()
        if deleted:
            s.add(OperationLog(action="delete", entity_type="ingredient", detail=f"deleted {deleted}"))
            s.commit()
        return jsonify({"deleted": deleted, "blocked": blocked})

# --- Dishes with items ---

@bp.route("/dishes/create-with-items", methods=["POST"])
def dishes_create_with_items():
    body = request.json or {}
    category_id = body.get("category_id")
    name = (body.get("name") or "").strip()
    items = body.get("items") or []
    if not category_id or not name:
        return jsonify({"error": "category_id and name required"}), 400
    from .services import create_dish_with_version
    rv = create_dish_with_version(category_id, name, "v1", items)
    return jsonify({"version_id": rv.id})

@bp.route("/recipes/<int:version_id>/items", methods=["PUT"])
def recipe_items_set(version_id):
    # Full replace items for a version
    items = request.json.get("items") or []
    with SessionLocal() as s:
        rv = s.get(RecipeVersion, version_id)
        if not rv:
            return jsonify({"error": "not found"}), 404
        olds = s.execute(select(RecipeItem).where(RecipeItem.recipe_version_id == rv.id)).scalars().all()
        for oi in olds:
            s.delete(oi)
        s.flush()
        to_add = []
        for idx, it in enumerate(items):
            ing = _get_or_create_ingredient_in_session(s, (it.get("name") or "").strip(), it.get("unit") or "g")
            to_add.append(RecipeItem(
                recipe_version_id=rv.id,
                ingredient_id=ing.id,
                amount=float(it.get("amount") or 0),
                unit=it.get("unit") or "g",
                order_index=idx,
            ))
        if to_add:
            s.add_all(to_add)
        s.add(OperationLog(action="update", entity_type="recipe_items", entity_id=version_id, detail=f"set {len(items)} items"))
        s.commit()
        return jsonify({"ok": True})
