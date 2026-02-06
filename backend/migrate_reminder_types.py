#!/usr/bin/env python3
"""
数据库迁移脚本：为 voice_reminders 表添加提醒类型字段
"""
import sqlite3
import os

DB_PATH = './menu.db'

def migrate():
    if not os.path.exists(DB_PATH):
        print(f"❌ 数据库文件不存在: {DB_PATH}")
        return False
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    try:
        print("开始迁移...")
        
        # 检查字段是否已存在
        cursor.execute("PRAGMA table_info(voice_reminders)")
        columns = [col[1] for col in cursor.fetchall()]
        
        # 添加 reminder_type 字段
        if 'reminder_type' not in columns:
            print("  添加 reminder_type 字段...")
            cursor.execute('''
                ALTER TABLE voice_reminders 
                ADD COLUMN reminder_type TEXT DEFAULT 'ai_voice'
            ''')
            print("  ✅ reminder_type 字段已添加")
        else:
            print("  ⚠️  reminder_type 字段已存在，跳过")
        
        # 添加 voice_model 字段
        if 'voice_model' not in columns:
            print("  添加 voice_model 字段...")
            cursor.execute('''
                ALTER TABLE voice_reminders 
                ADD COLUMN voice_model TEXT DEFAULT 'tts-1'
            ''')
            print("  ✅ voice_model 字段已添加")
        else:
            print("  ⚠️  voice_model 字段已存在，跳过")
        
        # 添加 audio_file_path 字段
        if 'audio_file_path' not in columns:
            print("  添加 audio_file_path 字段...")
            cursor.execute('''
                ALTER TABLE voice_reminders 
                ADD COLUMN audio_file_path TEXT
            ''')
            print("  ✅ audio_file_path 字段已添加")
        else:
            print("  ⚠️  audio_file_path 字段已存在，跳过")
        
        conn.commit()
        print("\n✅ 迁移完成！")
        
        # 显示表结构
        print("\n当前表结构:")
        cursor.execute("PRAGMA table_info(voice_reminders)")
        for col in cursor.fetchall():
            print(f"  - {col[1]} ({col[2]})")
        
        return True
        
    except Exception as e:
        print(f"\n❌ 迁移失败: {e}")
        conn.rollback()
        return False
    finally:
        conn.close()

if __name__ == '__main__':
    print("=" * 50)
    print("语音提醒表迁移脚本")
    print("=" * 50)
    print()
    
    success = migrate()
    
    print()
    if success:
        print("迁移成功！可以继续更新后端代码。")
    else:
        print("迁移失败，请检查错误信息。")
