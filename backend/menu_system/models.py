from sqlalchemy import Column, Integer, String, ForeignKey, Float, Boolean, DateTime, UniqueConstraint
from sqlalchemy.orm import relationship
from datetime import datetime
from .db import Base

class Cuisine(Base):
    __tablename__ = "cuisines"
    id = Column(Integer, primary_key=True)
    name = Column(String(128), unique=True, nullable=False)
    categories = relationship("Category", back_populates="cuisine", cascade="all, delete-orphan")

class Category(Base):
    __tablename__ = "categories"
    id = Column(Integer, primary_key=True)
    name = Column(String(128), nullable=False)
    sort_order = Column(Integer, default=0)
    cuisine_id = Column(Integer, ForeignKey("cuisines.id"), nullable=False)
    cuisine = relationship("Cuisine", back_populates="categories")
    dishes = relationship("Dish", back_populates="category", cascade="all, delete-orphan")
    __table_args__ = (UniqueConstraint("cuisine_id", "name", name="uq_category_cuisine_name"),)

class Dish(Base):
    __tablename__ = "dishes"
    id = Column(Integer, primary_key=True)
    name = Column(String(256), nullable=False)
    code = Column(String(64))
    price = Column(Float, default=0.0)
    description = Column(String(1024))
    category_id = Column(Integer, ForeignKey("categories.id"), nullable=False)
    category = relationship("Category", back_populates="dishes")
    versions = relationship("RecipeVersion", back_populates="dish", cascade="all, delete-orphan")
    __table_args__ = (UniqueConstraint("category_id", "name", name="uq_dish_category_name"),)

class Ingredient(Base):
    __tablename__ = "ingredients"
    id = Column(Integer, primary_key=True)
    name = Column(String(256), unique=True, nullable=False)
    default_unit = Column(String(16), default="g")
    type = Column(String(64))
    stock = Column(Float, default=0.0)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    nutrition = relationship("NutritionProfile", back_populates="ingredient", uselist=False, cascade="all, delete-orphan")

class IngredientChangeLog(Base):
    __tablename__ = "ingredient_change_logs"
    id = Column(Integer, primary_key=True)
    ingredient_id = Column(Integer, ForeignKey("ingredients.id"), nullable=False)
    field_name = Column(String(64), nullable=False)
    old_value = Column(String(256))
    new_value = Column(String(256))
    changed_at = Column(DateTime, default=datetime.utcnow)

class OperationLog(Base):
    __tablename__ = "operation_logs"
    id = Column(Integer, primary_key=True)
    action = Column(String(64), nullable=False)
    entity_type = Column(String(64), nullable=False)
    entity_id = Column(Integer)
    detail = Column(String(1024))
    created_at = Column(DateTime, default=datetime.utcnow)

class NutritionProfile(Base):
    __tablename__ = "nutrition_profiles"
    id = Column(Integer, primary_key=True)
    ingredient_id = Column(Integer, ForeignKey("ingredients.id"), nullable=False)
    calories_per_100g = Column(Float, default=0.0)
    protein_per_100g = Column(Float, default=0.0)
    fat_per_100g = Column(Float, default=0.0)
    carbs_per_100g = Column(Float, default=0.0)
    ingredient = relationship("Ingredient", back_populates="nutrition")

class RecipeVersion(Base):
    __tablename__ = "recipe_versions"
    id = Column(Integer, primary_key=True)
    dish_id = Column(Integer, ForeignKey("dishes.id"), nullable=False)
    version = Column(String(32), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    active = Column(Boolean, default=True)
    dish = relationship("Dish", back_populates="versions")
    items = relationship("RecipeItem", back_populates="version", cascade="all, delete-orphan")
    __table_args__ = (UniqueConstraint("dish_id", "version", name="uq_recipe_version"),)

class RecipeItem(Base):
    __tablename__ = "recipe_items"
    id = Column(Integer, primary_key=True)
    recipe_version_id = Column(Integer, ForeignKey("recipe_versions.id"), nullable=False)
    ingredient_id = Column(Integer, ForeignKey("ingredients.id"), nullable=False)
    amount = Column(Float, nullable=False)
    unit = Column(String(16), nullable=False)
    order_index = Column(Integer, default=0)
    version = relationship("RecipeVersion", back_populates="items")
    ingredient = relationship("Ingredient")

class VoiceReminder(Base):
    __tablename__ = "voice_reminders"
    id = Column(Integer, primary_key=True)
    time = Column(String(8), nullable=False)  # Format: "HH:MM"
    content = Column(String(512), nullable=False)
    enabled = Column(Boolean, default=True)
    reminder_type = Column(String(32), default='ai_voice')  # 'system', 'ai_voice', 'custom_audio'
    voice_model = Column(String(32), default='tts-1')  # 'tts-1', 'tts-1-hd'
    audio_file_path = Column(String(512))  # Path to custom audio file
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class PushSubscription(Base):
    __tablename__ = "push_subscriptions"
    id = Column(Integer, primary_key=True)
    endpoint = Column(String(512), nullable=False)
    p256dh_key = Column(String(256), nullable=False)
    auth_key = Column(String(256), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
