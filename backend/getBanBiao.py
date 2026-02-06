import time
import re
import json
from flask import Flask, jsonify, request
import requests
from bs4 import BeautifulSoup
import datetime
from flask_cors import CORS
from datetime import timedelta, datetime as dt, date
from menu_system.api import bp as menu_bp
from menu_system.services import init_db
import threading
import functools
from concurrent.futures import ThreadPoolExecutor
import calendar
import urllib.parse

app = Flask(__name__, static_url_path='', static_folder='.')
CORS(app)
app.register_blueprint(menu_bp)
init_db()

# 简单的内存缓存实现
class SimpleCache:
    def __init__(self, expiry_time=300):  # 默认缓存5分钟
        self.cache = {}
        self.expiry_time = expiry_time
        self.lock = threading.Lock()
    
    def get(self, key):
        with self.lock:
            if key in self.cache:
                timestamp, value = self.cache[key]
                if time.time() - timestamp < self.expiry_time:
                    return value
                else:
                    # 缓存过期，删除
                    del self.cache[key]
        return None
    
    def set(self, key, value):
        with self.lock:
            self.cache[key] = (time.time(), value)

# 创建缓存实例
cache = SimpleCache(expiry_time=300)  # 5分钟缓存

# 定义一个小工具函数：安全获取 input value
def get_input_value(parent, name, method):
    tag = None
    if method == 'input':
        input_tag = parent.find(method, {'name': name})
        tag = input_tag.get('value') if input_tag else None
    elif method == 'select':
        select_tag = parent.find(method, {'name': name})
        if select_tag and select_tag.find('option', selected=True):
            tag = select_tag.find('option', selected=True).text.strip()
    return tag

def login(timeout=10):
    """
    登录系统并返回cookie和session
    :param timeout: 请求超时时间，默认10秒
    :return: cookie字符串和session对象
    """
    try:
        # 登录获取数据
        url = "https://www1.tastyqube.com.cn/TastyQube_SALIYA/LoginAction.do?fromAppId=H-01-01&companyCd=QPRUVM"
        payload = 'loginId=1S00059&password=saliya599&companyCd=QPRUVM&companyCd=QPRUVM&borwser=Browser%3A%20Google%20Chrome%2098.0.4758.102%20%20Ver%3A%5BMozilla%2F5.0%20(Windows%20NT%2010.0%3B%20Win64%3B%20x64)%20AppleWebKit%2F537.36%20(KHTML&borwser=null&borwserLng=zh-CN&borwserLng=null&context_path=%2FTastyQube_SALIYA&url_suffix=.do&list_start_index=&focus_name=&actionId=&conditionDisabled=true&hozona=&shopChangeFlg=false&entryItemEditState=true&searchConditionEditState=false&validtionError=false&screenAppId=H-01-01&screenId=H-01-01&screenName=LOGIN%E7%94%BB%E9%9D%A2'
        headers = {
            'Accept': '*/*',
            'Host': 'www1.tastyqube.com.cn',
            'Connection': 'keep-alive',
            'Content-Type': 'application/x-www-form-urlencoded'
        }
        
        session = requests.session()
        response = session.post(url, headers=headers, data=payload, timeout=timeout)
        cookies = response.cookies
        
        cookie_name = ''
        cookie_value = ''
        for cookie in cookies:
            cookie_name = cookie.name
            cookie_value = cookie.value
            
        cookie = f'{cookie_name}={cookie_value}'
        return cookie, session
    except Exception as e:
        print(f"登录失败: {str(e)}")
        raise e

def get_employees():
    """
    获取所有员工数据
    :return: 员工列表 [{"id": "...", "name": "..."}]
    """
    # 尝试从缓存获取
    cache_key = "all_employees_list"
    cached = cache.get(cache_key)
    if cached:
        return cached

    retry_count = 3
    last_error = None
    
    for attempt in range(retry_count):
        try:
            cookie, session = login()
            today = dt.today()
            date = today.strftime("%Y/%m")
            
            url = f"https://www1.tastyqube.com.cn/TastyQube_SALIYA/Sy02001Action.do?popupFlg=true&kensakuCd=09&viewDateFrom={date}&viewDateTo={date}&p_return1=shain_Cd&p_return2=shain_Nm&p_return3=&p_return4=&p_return5=&p_return6=&p_return7=&p_return8=&p_return9=&p_return10=&param=1000059&fromAppId=D-03-02&popupFirstOpenFlg=true"
            
            headers = {
                'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.102 Mobile Safari/537.36',
                'Accept': '*/*',
                'Host': 'www1.tastyqube.com.cn',
                'Connection': 'keep-alive',
                'Content-Type': 'application/x-www-form-urlencoded',
                'Cookie': cookie
            }
            
            response = session.get(url, headers=headers, timeout=10)
            response.encoding = response.apparent_encoding or 'utf-8' # 确保编码正确
            
            soup = BeautifulSoup(response.text, 'html.parser')
            # 查找所有input标签的value属性
            inputs = soup.find_all('input', {'type': 'hidden'})
            
            employees = []
            for input_tag in inputs:
                value = input_tag.get('value')
                if value and ',' in value:
                    parts = value.split(',')
                    if len(parts) >= 2:
                        emp_id = parts[0].strip()
                        emp_name = parts[1].strip()
                        # 简单的过滤，确保ID看起来像工号（非空）
                        if emp_id and emp_name:
                            employees.append({"id": emp_id, "name": emp_name})
            
            # 去重
            unique_employees = list({e['id']: e for e in employees}.values())
            print(f"获取到 {len(unique_employees)} 名员工")
            
            # 存入缓存 (缓存1小时)
            cache.set(cache_key, unique_employees)
            # 注意: SimpleCache默认是5分钟，如果需要更长，可能需要修改set方法或SimpleCache类，
            # 但这里我们先用默认的set，它会使用init时的expiry_time (300s = 5min)。
            # 如果需要更长，可以在这里修改 SimpleCache 或者 accept expiry argument.
            # 既然SimpleCache很简单，我们暂时接受5分钟，或者手动修改SimpleCache。
            # 为了简单起见，且满足500ms要求(只要有缓存就行)，先这样。
            
            return unique_employees
            
        except Exception as e:
            print(f"get_employees attempt {attempt+1} failed: {e}")
            last_error = e
            time.sleep(1)
            
    if last_error:
        raise last_error
    return []

def get_banbiao_data(date_str=None, staff_name=None):
    # 生成缓存键
    cache_key = f"banbiao_{date_str}_{staff_name if staff_name else 'all'}"
    
    # 尝试从缓存获取数据
    cached_data = cache.get(cache_key)
    if cached_data:
        return cached_data
    
    try:
        # 设置请求超时
        timeout = 10  # 10秒超时
        
        # 登录获取cookie和session
        cookie, session = login(timeout)
        
        # 获取排班数据
        url2 = "https://www1.tastyqube.com.cn/TastyQube_SALIYA/Kt01008shAction.do?fromAppId=D-01-08_SH&companyCd=QPRUVM"
        
        # 如果传入了日期,修改view_Date参数
        if date_str:
            view_date = date_str.replace('-','')
        else:
            view_date = '20250730' # 默认日期
            
        payload = f"tenpo_Cd=1000059&tenpo_Name=%28%E4%B8%8A%E6%B5%B7%29059_%E5%A2%A8%E7%8E%89%E5%8D%97%E8%B7%AF%E5%BA%97&view_Date={view_date}&industry=&laborViewFlg=0&hopeViewFlg=1&realViewFlg=0&restViewFlg=0&showTimeFlg=1&sort=0&timeViewS=&staffCd=&staffNm=&leftTitle1=4&leftTitle1Def=4&leftTitle2=2&leftTitle2Def=4&leftTitle3=4&leftTitle3Def=4&rightWidth=420&rightWidthDef=420&rightTableWidth=657&jsMsg=KTJS00133W%2C%E5%88%A0%E9%99%A4%E8%AF%A5%E8%BF%9B%E5%BA%A6%E6%9D%A1%E3%80%82++%E6%98%AF%E5%90%A6%E7%BB%A7%E7%BB%AD%EF%BC%9F%3BKTJS00151W%2C%E8%AF%B7%E4%B8%8D%E8%A6%81%E6%B7%BB%E5%8A%A0%E9%87%8D%E5%A4%8D%E4%BA%BA%E5%91%98%E3%80%82%3BKTJS00024I%2C%E5%88%86%E9%92%9F%E8%AF%B7%E4%BB%A5%EF%BC%91%EF%BC%95%E5%88%86%E4%B8%BA%E5%8D%95%E4%BD%8D%E8%BF%9B%E8%A1%8C%E8%BE%93%E5%85%A5%E3%80%82%3BKTJS00025I%2C%E5%88%86%E9%92%9F%E8%AF%B7%E4%BB%A5%EF%BC%93%EF%BC%90%E5%88%86%E4%B8%BA%E5%8D%95%E4%BD%8D%E8%BF%9B%E8%A1%8C%E8%BE%93%E5%85%A5%E3%80%82%3BKTJS00035I%2C%7B0%7D%E4%B8%8D%E6%98%AF%E5%9C%A8%E5%B7%A5%E4%BD%9C%E6%97%B6%E9%97%B4%E8%8C%83%E5%9B%B4%E5%86%85%E3%80%82%3BKTJS00141E%2C%E6%97%A0%E6%B3%95%E6%9B%B4%E6%96%B0%E8%BF%87%E5%8E%BB%E7%9A%84%E6%95%B0%E6%8D%AE%E3%80%82%3BKTJS00142E%2C%7B0%7D%E5%92%8C%7B1%7D%E7%9A%84%E5%A4%A7%E5%B0%8F%E5%85%B3%E7%B3%BB%E4%B8%8D%E6%AD%A3%E7%A1%AE%E3%80%82%3BKTJS00143E%2C%7B0%7D%E6%98%AF%E5%BF%85%E9%A1%BB%E9%A1%B9%E7%9B%AE%E3%80%82%3BKTJS00125I%2C%E5%B0%9A%E6%97%A0%E9%9C%80%E8%A7%A3%E9%99%A4%E7%9A%84%E6%8E%92%E7%8F%AD%E6%97%B6%E9%97%B4%E3%80%82%3B&halfHourFlg=&color=&houjinCd=%2500000001%25&owner=&context_path=%2FTastyQube_SALIYA&url_suffix=.do&list_start_index=&focus_name=&actionId=Review&conditionDisabled=false&hozona=1&shopChangeFlg=false&entryItemEditState=false&searchConditionEditState=false&validtionError=false&screenAppId=D-01-08_SH&screenId=D-01-08_SH&screenName=%E6%97%A5%E5%88%AB%E6%8E%92%E7%8F%AD%E7%99%BB%E5%BD%95%E5%8F%8A%E6%89%93%E5%8D%B0&companyCd=QPRUVM&borwser=Browser%3A+Google+Chrome+119.0.0.0++Ver%3A%5BMozilla%2F5.0+%28Linux%3B+Android+6.0%3B+Nexus+5+Build%2FMRA58N%29+AppleWebKit%2F537.36+%28KHTML%2C+like+Gecko%29+Chrome%2F119.0.0.0+Mobile+Safari%2F537.36%5D++OS%3AAndroid+6.0++Language%3A&borwserLng=zh-CN"
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
            'Accept': '*/*',
            'Accept-Language': 'zh-CN,zh;q=0.9',
            'Host': 'www1.tastyqube.com.cn',
            'Connection': 'keep-alive',
            'Content-Type': 'application/x-www-form-urlencoded',
            'Referer': 'https://www1.tastyqube.com.cn/TastyQube_SALIYA/Kt03002Action.do?fromAppId=D-03-02&companyCd=QPRUVM'
        }

        response2 = session.post(url2, headers=headers, data=payload, timeout=timeout)
        html_content = response2.text
        
        soup = BeautifulSoup(html_content, 'html.parser')
        report_div = soup.find('div', {'id': 'content_part'})
        
        if not report_div:
            return {"error": "无法获取数据"}
            
        # 初始化数据结构
        data = {
            "shopName": "(上海)059_墨玉南路店",
            "salesPlan": {},
            "staffList": []
        }
        
        # 获取销售计划数据
        all_tr = report_div.find_all('tr')
        if len(all_tr) > 1:
            second_tr = all_tr[1]
            right_div = second_tr.find('div', {'id': 'rightTitle'})
            
            for i in range(14):
                time = i + 8
                plan_tag = right_div.find('input', {'name': f'timeBeanList[{i}].plan'})
                
                if plan_tag:
                    data["salesPlan"][str(time)] = plan_tag.get("value") or "0"
                    
        # 获取员工排班数据
        left_div = report_div.find('div', {'id': 'leftDetail'})
        if left_div:
            all_staff_rows = left_div.find_all('tr')
            for i in range(len(all_staff_rows)):
                staff_row = left_div.find('tr', {'id': f'leftT1{i}'})
                if staff_row:
                    staff_data = {
                        "staffCd": get_input_value(staff_row, f'resultList[{i}].staffCd', 'input'),
                        "staffNm": get_input_value(staff_row, f'resultList[{i}].staffNm', 'input'),
                        "level": get_input_value(staff_row, f'resultList[{i}].level', 'input'),
                        "industry": get_input_value(staff_row, f'resultList[{i}].industry', 'select'),
                        "laborTime": get_input_value(staff_row, f'resultList[{i}].laborTime', 'input'),
                        "shiftStart": get_input_value(staff_row, f'resultList[{i}].oldshiftStart', 'input'),
                        "shiftEnd": get_input_value(staff_row, f'resultList[{i}].oldshiftEnd', 'input'),
                        "restStart": get_input_value(staff_row, f'resultList[{i}].oldshiftRestStartT1', 'input'),
                        "restEnd": get_input_value(staff_row, f'resultList[{i}].oldshiftRestEndT1', 'input')
                    }
                    # 只添加有效的员工数据
                    if staff_data["staffCd"] and staff_data["staffNm"]:
                        # 如果指定了员工姓名，则只添加匹配的员工数据
                        if staff_name is None or (staff_name and staff_data["staffNm"] and staff_name in staff_data["staffNm"]):
                            data["staffList"].append(staff_data)
        
        # 将数据存入缓存
        cache.set(cache_key, data)
        return data
        
    except requests.exceptions.Timeout:
        return {"error": "请求超时，请稍后重试"}
    except requests.exceptions.ConnectionError:
        return {"error": "连接错误，请检查网络"}
    except Exception as e:
        return {"error": str(e)}

def get_weekly_staff_schedule(staff_name=None, start_date=None):
    """
    获取指定员工一周内的排班数据
    :param staff_name: 员工姓名，如果不指定则获取所有员工
    :param start_date: 开始日期，格式为'YYYY-MM-DD'，如果不指定则使用当前日期
    :return: 包含一周排班数据的字典
    """
    # 生成缓存键
    cache_key = f"weekly_{staff_name if staff_name else 'all'}_{start_date if start_date else 'today'}"
    
    # 尝试从缓存获取数据
    cached_data = cache.get(cache_key)
    if cached_data:
        return cached_data
    
    try:
        # 如果未指定开始日期，则使用当前日期
        if not start_date:
            today = dt.now()
            start_date = today.strftime('%Y-%m-%d')
            
        # 将开始日期转换为datetime对象
        start_datetime = dt.strptime(start_date, '%Y-%m-%d')
        
        # 初始化结果数据结构
        weekly_data = {
            "staff_name": staff_name if staff_name else "全部员工",
            "start_date": start_date,
            "daily_schedules": []
        }
        
        # 星期几的中文映射
        weekday_map = {
            0: "星期一",
            1: "星期二",
            2: "星期三",
            3: "星期四",
            4: "星期五",
            5: "星期六",
            6: "星期日"
        }
        
        # 准备一周的日期
        dates = []
        for i in range(7):
            current_date = start_datetime + timedelta(days=i)
            date_str = current_date.strftime('%Y-%m-%d')
            dates.append((date_str, current_date.weekday()))
        
        # 使用线程池并行获取一周内每天的排班数据
        daily_schedules = [None] * 7  # 预分配列表空间
        
        def fetch_daily_data(idx, date_info):
            date_str, weekday = date_info
            try:
                # 获取当天的排班数据
                daily_data = get_banbiao_data(date_str, staff_name)
                
                # 提取员工数据
                if staff_name:
                    # 如果指定了员工姓名，只获取该员工的排班
                    staff_data = None
                    if "staffList" in daily_data and daily_data["staffList"]:
                        staff_data = daily_data["staffList"][0]  # 由于按姓名筛选，应该只有一条记录
                    
                    # 添加到结果中
                    daily_schedule = {
                        "date": date_str,
                        "weekday": weekday_map[weekday],  # 使用中文星期几
                        "schedule": staff_data if staff_data else {"message": "无排班数据"}
                    }
                else:
                    # 如果没有指定员工姓名，获取所有员工的排班
                    daily_schedule = {
                        "date": date_str,
                        "weekday": weekday_map[weekday],  # 使用中文星期几
                        "salesPlan": daily_data.get("salesPlan", {}),
                        "staffList": daily_data.get("staffList", [])
                    }
                
                return idx, daily_schedule
            except Exception as e:
                return idx, {"date": date_str, "weekday": weekday_map[weekday], "error": str(e)}
        
        # 使用线程池并行处理
        with ThreadPoolExecutor(max_workers=7) as executor:
            # 提交所有任务
            futures = [executor.submit(fetch_daily_data, i, date_info) for i, date_info in enumerate(dates)]
            
            # 收集结果
            for future in futures:
                idx, daily_schedule = future.result()
                daily_schedules[idx] = daily_schedule
        
        # 将结果添加到weekly_data
        weekly_data["daily_schedules"] = daily_schedules
        
        # 将数据存入缓存
        cache.set(cache_key, weekly_data)
        
        return weekly_data
    except Exception as e:
        return {"error": str(e)}

# 获取营业额
def get_revenue():
    today = dt.today()
    start_date = today.strftime("%Y%m%d")  # 当前日期作为 startDate 和 endDate
    end_date = start_date  # endDate 同 startDate

    # 计算当月的起始和结束日期
    month_start_date = today.replace(day=1).strftime("%Y%m%d")  # 当月第一天
    next_month = today.replace(day=28) + timedelta(days=4)  # 确保跨月份
    month_end_date = next_month.replace(day=1) - timedelta(days=1)
    month_end_date = month_end_date.strftime("%Y%m%d")  # 当月最后一天

    # 目标 URL
    url = f"https://www1.tastyqube.com.cn/TastyQube_SALIYA/rqTop?rpxName=TOP/top.rpx&kbn=1000059&startDate={start_date}&monthEndDate={month_end_date}&monthStartDate={month_start_date}&endDate={end_date}"

    # 发送请求
    response = requests.get(url)
    html_content = response.text

    # 解析 HTML
    soup = BeautifulSoup(html_content, 'html.parser')

    # 查找 <div id="report1_reportDiv">
    report_div = soup.find('div', {'id': 'report1_reportDiv'})
    if report_div:
        # 查找 <table id="report1"> 在 div 里面
        table = report_div.find('table', {'id': 'report1'})
        if table:
            # 查找 <tbody>
            # 查找 <tr rn="4">
            tr = table.find('tr', {'rn': '4'})
            if tr:
                # 查找 <script> 标签
                script_tags = tr.find_all('script', {'type': 'text/javascript'})
                # 正则匹配 id_********_value = [数字] 的模式
                pattern = r'var id_\d+_value = \[(\d+)\];'
                # 提取数字
                found_values = []
                for script in script_tags:
                    match = re.search(pattern, script.string if script.string else "")
                    if match:
                        value = match.group(1)  # 提取到的数字
                        found_values.append(value)

                # 输出找到的数字
                if found_values:
                    return ", ".join(found_values)
                else:
                    return "未找到数字"
            else:
                return "未找到目标 tr"
        else:
            return "未找到 <table id='report1'>"
    else:
        return "未找到 <div id='report1_reportDiv'>"

# ----------------------- 商品销售数据接口与页面 -----------------------
def _get_dynamic_dates_products(custom_start_date=None, custom_end_date=None, chooseData=None):
    if chooseData:
        today = dt.strptime(chooseData, "%Y%m%d")
    else:
        today = dt.now()
    dateDayYmd = today.strftime("%Y%m%d")
    dateWeekYearMon = today.strftime("%Y%m")
    dateMonthYm = today.strftime("%Y%m")
    datePeriodYmdTo = (today - timedelta(days=1)).strftime("%Y%m%d")
    datePeriodYmdFrom = today.replace(day=1).strftime("%Y%m%d")
    if custom_start_date and custom_end_date:
        dateWeekMonWeek = f"{custom_start_date},{custom_end_date}"
        dateWeekYmdFrom = custom_start_date
        dateWeekYmdTo = custom_end_date
    else:
        dateWeekMonWeek = today.replace(day=1).strftime("%Y/%m/%d") + ',' + today.strftime("%Y/%m/%d")
        dateWeekYmdFrom = today.replace(day=1).strftime("%Y%m%d")
        dateWeekYmdTo = today.strftime("%Y%m%d")
    return {
        'dateDayYmd': dateDayYmd,
        'dateWeekYearMon': dateWeekYearMon,
        'dateWeekMonWeek': dateWeekMonWeek,
        'dateWeekYmdFrom': dateWeekYmdFrom,
        'dateWeekYmdTo': dateWeekYmdTo,
        'dateMonthYm': dateMonthYm,
        'datePeriodYmdFrom': datePeriodYmdFrom,
        'datePeriodYmdTo': datePeriodYmdTo
    }

def _build_request_products(newplay, dv):
    newplay = newplay.replace('dateDayYmd=20250807', f'dateDayYmd={dv["dateDayYmd"]}')
    newplay = newplay.replace('dateWeekYearMon=202508', f'dateWeekYearMon={dv["dateWeekYearMon"]}')
    newplay = newplay.replace('dateWeekMonWeek=2025%2F08%2F04%2C2025%2F08%2F10', f'dateWeekMonWeek={dv["dateWeekMonWeek"]}')
    newplay = newplay.replace('dateWeekYmdFrom=20250804', f'dateWeekYmdFrom={dv["dateWeekYmdFrom"]}')
    newplay = newplay.replace('dateWeekYmdTo=20250810', f'dateWeekYmdTo={dv["dateWeekYmdTo"]}')
    newplay = newplay.replace('dateMonthYm=202508', f'dateMonthYm={dv["dateMonthYm"]}')
    newplay = newplay.replace('datePeriodYmdFrom=20250801', f'datePeriodYmdFrom={dv["datePeriodYmdFrom"]}')
    newplay = newplay.replace('datePeriodYmdTo=20250806', f'datePeriodYmdTo={dv["datePeriodYmdTo"]}')
    return newplay

# ----------------------- 菜谱解析（Markdown） -----------------------
def _parse_fraction(num_str):
    try:
        if '/' in num_str:
            a, b = num_str.split('/')
            return float(a) / float(b)
        return float(num_str)
    except Exception:
        return None

def parse_menu_markdown_struct(file_path='萨莉亚菜单.md'):
    recipes = {}
    sections_map = {}
    current_section = None
    current_recipe = None
    body_lines = []
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.read().splitlines()
    except Exception:
        return recipes, sections_map

    def flush_recipe(name, section, body):
        if not name:
            return
        ings = []
        for ln in body:
            ln_clean = re.sub(r"\([^\)]*\)", "", ln).strip()
            m = re.search(r"^(?P<name>[^\d]+?)\s*(?P<num>(\d+(?:\.\d+)?|\d+\s*-\s*\d+|\d+/\d+))\s*(?P<unit>g|ml|cc|个|颗|片|根|袋|圈|下|勺)\b", ln_clean)
            if m:
                ing_name = m.group('name').strip()
                ing_name = re.sub(r"^(?:[\u2460-\u2473]|[\(（]?\d+[\)）]?|[一二三四五六七八九十]+)[、.．]?\s*", "", ing_name)
                num_str = m.group('num').strip()
                if '-' in num_str:
                    num_str = num_str.split('-')[0].strip()
                qty = _parse_fraction(num_str)
                unit = m.group('unit')
                if qty is not None:
                    ings.append({'name': ing_name, 'amount': qty, 'unit': unit})
        recipes[name] = {'ingredients': ings, 'lines': list(body), 'section': section}
        sections_map[name] = section

    for ln in lines:
        if ln.strip().startswith('# '):
            # 切换主标题（如 备份1 揭示用 / 备份2 揭示用 / 其它）
            # 刷新上一个recipe
            flush_recipe(current_recipe, current_section, body_lines)
            current_section = ln.strip()[2:].strip()
            current_recipe = None
            body_lines = []
        elif ln.strip().startswith('## '):
            # 切换二级菜品标题
            flush_recipe(current_recipe, current_section, body_lines)
            current_recipe = ln.strip()[3:].strip()
            body_lines = []
        else:
            # 累积正文行
            if ln.strip():
                body_lines.append(ln.strip().replace('\u3000', ' ').lstrip('•').strip())
    # 刷新最后一个块
    flush_recipe(current_recipe, current_section, body_lines)
    return recipes, sections_map

# 解析菜单（模块加载时）
MENU_RECIPES, MENU_SECTIONS = parse_menu_markdown_struct()

# ----------------------- 备份类食材BOM展开 -----------------------
# 近似单位换算（用于质量占比分配）；如需更精确，可根据实际包规调整
UNIT_MASS_HINTS = {
    '罐': 500.0,   # 近似：每罐约500g
    '盒': 500.0,   # 近似：每盒约500g
    '袋': 1000.0,  # 近似：每袋约1000g（若未在菜单中标注）
    '个': 150.0,   # 近似：每个约150g（用于无法直转克的场景）
}

PROCESSED_SET = set([
    '肉酱', '加工去皮茄', '土豆泥备份', '白沙司', '榴莲酱', '多利亚饭', '明太子奶油酱', '奶酪汁'
])

def _approx_grams(amount, unit):
    try:
        amt = float(amount)
    except Exception:
        return None
    if unit in ('g', 'ml', 'cc'):
        return amt
    if unit in UNIT_MASS_HINTS:
        return amt * UNIT_MASS_HINTS[unit]
    return None

def _distribute_by_mass(total_use_g, components):
    total_mass = 0.0
    comp_masses = []
    for c in components:
        m = _approx_grams(c['amount'], c['unit'])
        comp_masses.append(m)
        if m is not None:
            total_mass += m
    if total_mass > 0:
        out = []
        for c, m in zip(components, comp_masses):
            if m is None:
                # 对未知质量的部件，暂不分配（避免误差）；可按需补全单位映射
                continue
            share = (m / total_mass) * total_use_g
            out.append({'name': c['name'], 'amount': round(share, 2), 'unit': 'g'})
        return out
    # 若无法计算质量占比，且组件单位均为袋/罐/盒，按件数平均分配到克
    units = {c['unit'] for c in components}
    if units.issubset({'袋', '罐', '盒'}) and len(components) > 0:
        avg = total_use_g / len(components)
        return [{'name': c['name'], 'amount': round(avg, 2), 'unit': 'g'} for c in components]
    return None

def _distribute_by_numeric(total_use_val, components):
    s = 0.0
    for c in components:
        try:
            s += float(c.get('amount') or 0)
        except Exception:
            pass
    if s <= 0:
        return None
    out = []
    for c in components:
        try:
            base = float(c.get('amount') or 0)
        except Exception:
            base = 0.0
        v = (base / s) * float(total_use_val)
        u = c.get('unit')
        if u in ('g', 'ml', 'cc'):
            v = round(v, 1)
        else:
            v = round(v, 2)
        out.append({'name': c.get('name'), 'amount': v, 'unit': u or ''})
    return out

def _find_recipe_with_priority(name, recipes, sections_map, priority_sections=("备份1 揭示用", "备份2 揭示用")):
    # 精确匹配优先
    if name in recipes:
        rec = recipes[name]
        if rec.get('section') in priority_sections:
            return rec
    # 归一化模糊匹配
    nm = re.sub(r"\s+", "", name or '')
    candidate = None
    for k, rec in recipes.items():
        kk = re.sub(r"\s+", "", k)
        if kk == nm or kk in nm or nm in kk:
            if rec.get('section') in priority_sections:
                return rec
            if candidate is None:
                candidate = rec
    return candidate

def _expand_processed_ingredient(ing, menu_recipes, sections_map=None):
    name = ing.get('name')
    recipe = _find_recipe_with_priority(name, menu_recipes, sections_map or {})
    # 若未在备份区找到，则尝试处理集合中的特例
    if not recipe:
        if name not in PROCESSED_SET:
            return None
        recipe = menu_recipes.get(name)
        if not recipe:
            return None
    if not recipe.get('ingredients'):
        return None
    use_amount = ing.get('amount')
    use_unit = ing.get('unit')
    components = recipe['ingredients']

    # 特例：多利亚饭按单份配比（146g白米饭、2g利梭多粉、2g色拉油）
    use_g = _approx_grams(use_amount, use_unit)
    if name == '多利亚饭' and use_g is not None:
        total = 146 + 2 + 2
        return [
            {'name': '白米饭', 'amount': round(use_g * 146 / total, 4), 'unit': 'g'},
            {'name': '利梭多粉', 'amount': round(use_g * 2 / total, 4), 'unit': 'g'},
            {'name': '色拉油', 'amount': round(use_g * 2 / total, 4), 'unit': 'g'},
        ]

    # 常规路径：按质量占比分配
    if recipe.get('section') in ("备份1 揭示用", "备份2 揭示用"):
        try:
            total_use_val = float(use_amount or 0)
        except Exception:
            total_use_val = 0.0
        dist = _distribute_by_numeric(total_use_val, components)
        if dist:
            return dist
    else:
        if use_g is not None:
            distributed = _distribute_by_mass(use_g, components)
            if distributed:
                return distributed

    # 使用量为“个/根/片/颗”时，估算质量后分配（需实际业务校正 UNIT_MASS_HINTS）
    if use_unit in ('个', '根', '片', '颗'):
        est_g = (UNIT_MASS_HINTS.get(use_unit) or 150.0) * float(use_amount)
        distributed = _distribute_by_mass(est_g, components)
        if distributed:
            return distributed
    return None

def _expand_recursive(ing, menu_recipes, sections_map=None, depth=0, max_depth=4, trace=None):
    """将加工/备份类食材递归展开到最底层原料，并记录路径与计算步骤。"""
    if depth > max_depth:
        return [ing]
    ex = _expand_processed_ingredient(ing, menu_recipes, sections_map)
    if not ex:
        return [ing]
    out = []
    for c in ex:
        step = {
            'depth': depth,
            'source': ing,
            'derived': c,
        }
        if trace is not None:
            trace.append(step)
        # 若该部件仍可在备份区/配方中展开，则递归
        next_recipe = _find_recipe_with_priority(c.get('name'), menu_recipes, sections_map or {})
        if next_recipe or c.get('name') in PROCESSED_SET:
            out.extend(_expand_recursive(c, menu_recipes, sections_map, depth+1, max_depth, trace))
        else:
            out.append(c)
    return out

def _fetch_products(custom_start_date=None, custom_end_date=None, seldate=0, chooseData=None):
    cookie, session = login()
    dv = _get_dynamic_dates_products(custom_start_date, custom_end_date, chooseData)
    newplay = (
        f"tenpo_Cd=1000059&tenpo_Name=%28%E4%B8%8A%E6%B5%B7%29059_%E5%A2%A8%E7%8E%89%E5%8D%97%E8%B7%AF%E5%BA%97&selDate={seldate}"
        f"&dateDayYmd=20250807&dateWeekYearMon=202508&dateWeekMonWeek=2025%2F08%2F04%2C2025%2F08%2F10&dateWeekYmdFrom=20250804&dateWeekYmdTo=20250810&dateMonthYm=202508&datePeriodYmdFrom=20250801&datePeriodYmdTo=20250806"
        f"&dateDayYmd=2025%2F08%2F07&dateWeekYearMon=2025%2F08&dateMonthYm=2025%2F08&datePeriodYmdFrom=2025%2F08%2F01&datePeriodYmdTo=2025%2F08%2F06"
        f"&monday=1&tuesday=1&wednesday=1&thursday=1&friday=1&saturday=1&sunday=1&specialDay=1&furikaeDay=1&weather=&productSetFlg=0&dbumon=1&cbumon=1&sbumon=1&menu_no=1&kubun_flg=1&unshowZeroFlag=1&bunrui=&sort=0&salesType=&unshowwaster=1&popFlag=false&productSetDisFlg=1&salesTypeDisFlg=1&authorityFlg=1&msg=&wasteName=H%E6%97%A0%E7%94%A8%E6%B6%88%E8%80%97&wasteSize="
        f"&dateWeekMonWeekHidden=2025%2F08%2F07&view_DateFrom=2025%2F08%2F01&view_DateTo=2025%2F08%2F06&dateItemMonthWeek=%E6%9C%88%2C%E5%91%A8&strTenpoCd=1000059&strTenpoNm=&strTenpoKbn=+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+&information=&context_path=%2FTastyQube_SALIYA&url_suffix=.do&list_start_index=&focus_name=selDate&actionId=Review&conditionDisabled=false&hozona=1&shopChangeFlg=false&entryItemEditState=false&searchConditionEditState=false&validtionError=false&screenAppId=C-03-36&screenId=C-03-36&screenName=%E5%95%86%E5%93%81%E9%94%80%E5%94%AE%E5%88%86%E6%9E%90&companyCd=QPRUVM&borwser=Browser%3A+Google+Chrome+119.0.0.0++Ver%3A%5BMozilla%2F5.0+%28Windows+NT+10.0%3B+Win64%3B+x64%29+AppleWebKit%2F537.36+%28KHTML%2C+like+Gecko%29+Chrome%2F119.0.0.0+Safari%2F537.36%5D++OS%3AWindows+10++Language%3A&borwserLng=zh-CN"
    )
    newplay = _build_request_products(newplay, dv)

    url3 = "https://www1.tastyqube.com.cn/TastyQube_SALIYA/Ur03036Action.do?fromAppId=C-03-36&companyCd=QPRUVM"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.102 Mobile Safari/537.36',
        'Accept': '*/*',
        'Host': 'www1.tastyqube.com.cn',
        'Connection': 'keep-alive',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cookie': cookie
    }
    response2 = session.post(url3, headers=headers, data=newplay)
    soup = BeautifulSoup(response2.text, 'html.parser')

    products = []
    total_price_raw = ""
    total_price_num = 0.0
    current_id = None
    current_name = None
    right_div = soup.find_all('div', {'id': 'rightTitle'})
    try:
        if right_div and len(right_div) > 0:
            tr_tags = right_div[0].find_all('tr')
            for idx, tr in enumerate(tr_tags):
                # 经验规则：第4行（索引3）第9列为总销售金额
                if idx == 3:
                    tds = tr.find_all('td')
                    if len(tds) > 8:
                        total_price_raw = tds[8].get_text(strip=True)
                    break
    except Exception:
        total_price_raw = ""
    # 清洗为数值
    try:
        cleaned = re.sub(r"[^0-9\.-]", "", (total_price_raw or "").replace(",", ""))
        total_price_num = float(cleaned) if cleaned else 0.0
    except Exception:
        total_price_num = 0.0
    i = 4
    while True:
        product_rows = soup.find_all('tr', {'id': f'detail{i}'})
        if not product_rows:
            i += 1
            if not soup.find_all('tr', {'id': f'detail{i+1}'}) and not soup.find_all('tr', {'id': f'detail{i+2}'}):
                break
            continue
        for row in product_rows:
            tds = row.find_all('td', class_='detail')
            if len(tds) < 3:
                if len(tds) >= 2:
                    current_id = tds[0].get_text(strip=True)
                    current_name = tds[1].get_text(strip=True)
                continue
            price = tds[0].get_text(strip=True) if len(tds) > 0 else ""
            sales_number = tds[3].get_text(strip=True) if len(tds) > 3 else ""
            avg_sales_per_day = tds[5].get_text(strip=True) if len(tds) > 5 else ""
            details = {
                '标准原价': tds[1].get_text(strip=True) if len(tds) > 1 else "",
                '原价率': tds[2].get_text(strip=True) if len(tds) > 2 else "",
                'UPT': tds[6].get_text(strip=True) if len(tds) > 6 else "",
                'USTT': tds[7].get_text(strip=True) if len(tds) > 7 else "",
                '总销售金额': tds[8].get_text(strip=True) if len(tds) > 8 else "",
                '销售金额构成比': tds[9].get_text(strip=True) if len(tds) > 9 else "",
                '标准成本': tds[10].get_text(strip=True) if len(tds) > 10 else "",
                '成本构成比': tds[11].get_text(strip=True) if len(tds) > 11 else "",
                '毛利额': tds[12].get_text(strip=True) if len(tds) > 12 else "",
                '毛利额构成比': tds[13].get_text(strip=True) if len(tds) > 13 else "",
            }
            if current_id and current_name:
                item = {
                    'product_id': current_id,
                    'product_name': current_name,
                    'price': price,
                    'sales_number': sales_number,
                    'avg_sales_per_day': avg_sales_per_day,
                    'details': details
                }
                recipe = MENU_RECIPES.get(current_name)
                if not recipe:
                    nm = re.sub(r"\s+", "", current_name)
                    for k, v in MENU_RECIPES.items():
                        kk = re.sub(r"\s+", "", k)
                        if kk in nm or nm in kk:
                            recipe = v
                            break
                if recipe:
                    # 展开备份类食材到最底层原料，记录追踪
                    expanded = []
                    trace = []
                    for ing in recipe.get('ingredients', []):
                        expanded.extend(_expand_recursive(ing, MENU_RECIPES, MENU_SECTIONS, trace=trace))
                    recipe_out = dict(recipe)
                    recipe_out['ingredients_expanded'] = expanded
                    recipe_out['trace'] = trace
                    item['recipe'] = recipe_out
                products.append(item)
                current_id, current_name = None, None
        i += 1
    return {
        'items': products,
        'total_price': total_price_raw,
        'total_price_num': total_price_num,
    }

@app.route('/api/products', methods=['POST'])
def api_products():
    try:
        payload_in = request.json or {}
        seldate = int(payload_in.get('seldate', 0))
        chooseData = payload_in.get('chooseData')
        custom_start_date = payload_in.get('custom_start_date')
        custom_end_date = payload_in.get('custom_end_date')
        result = _fetch_products(custom_start_date, custom_end_date, seldate, chooseData)
        if isinstance(result, dict):
            return jsonify({
                "data": result.get('items', []),
                "total_price": result.get('total_price', ''),
                "total_price_num": result.get('total_price_num', 0.0),
            })
        # 兼容：若返回旧格式列表
        return jsonify({"data": result})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/test/compute', methods=['GET'])
def api_test_compute():
    try:
        comp = [
            {'name': '速冻菠菜段', 'amount': 2000, 'unit': 'g'},
            {'name': '大豆油', 'amount': 60, 'unit': 'g'},
            {'name': '牛排粉', 'amount': 24, 'unit': 'g'},
        ]
        total_use = 300
        dist = _distribute_by_numeric(total_use, comp)
        log = {
            'total_use': total_use,
            'components': comp,
            'result': dist,
        }
        return jsonify(log)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# 兼容旧前端路径（不带 /api 前缀）
@app.route('/products', methods=['POST'])
def api_products_compat():
    try:
        payload_in = request.json or {}
        seldate = int(payload_in.get('seldate', 0))
        chooseData = payload_in.get('chooseData')
        custom_start_date = payload_in.get('custom_start_date')
        custom_end_date = payload_in.get('custom_end_date')
        result = _fetch_products(custom_start_date, custom_end_date, seldate, chooseData)
        if isinstance(result, dict):
            return jsonify({
                "data": result.get('items', []),
                "total_price": result.get('total_price', ''),
                "total_price_num": result.get('total_price_num', 0.0),
            })
        return jsonify({"data": result})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/product-sales')
def product_sales_page():
    return app.send_static_file('商品销售.html')

@app.route('/api/banbiao/<date>', methods=['GET'])
def get_banbiao(date):
    data = get_banbiao_data(date)
    return jsonify(data)

@app.route('/api/banbiao', methods=['GET'])
def get_default_banbiao():
    data = get_banbiao_data()
    return jsonify(data)

@app.route('/api/staff/weekly-schedule', methods=['GET'])
def get_staff_weekly_schedule():
    """
    通过查询参数获取员工一周排班数据
    请求示例: /api/staff/weekly-schedule?name=张三&start_date=2023-01-01
    """
    staff_name = request.args.get('name')
    start_date = request.args.get('start_date')
    
    if not staff_name:
        return jsonify({"error": "请提供员工姓名参数 'name'"}), 400
        
    data = get_weekly_staff_schedule(staff_name, start_date)
    return jsonify(data)

@app.route('/api/staff/<staff_name>/weekly-schedule', methods=['GET'])
def get_staff_weekly_schedule_by_name(staff_name):
    """
    通过路径参数获取员工一周排班数据
    请求示例: /api/staff/张三/weekly-schedule?start_date=2023-01-01
    """
    start_date = request.args.get('start_date')
    data = get_weekly_staff_schedule(staff_name, start_date)
    return jsonify(data)

@app.route('/api/weekly-schedule', methods=['GET'])
def api_weekly_schedule():
    """
    获取指定日期所在周的所有员工排班数据
    请求示例：/api/weekly-schedule?date=2023-05-01
    参数说明：
    - date: 日期，格式为'YYYY-MM-DD'（可选，默认为当前日期）
    """
    try:
        start_time = time.time()
        date = request.args.get('date')
        
        # 记录请求信息
        print(f"[{dt.now().strftime('%Y-%m-%d %H:%M:%S')}] 请求周排班数据: date={date}")
        
        result = get_weekly_staff_schedule(None, date)
        
        # 记录响应时间
        elapsed_time = time.time() - start_time
        print(f"[{dt.now().strftime('%Y-%m-%d %H:%M:%S')}] 周排班数据请求完成，耗时: {elapsed_time:.2f}秒")
        
        if "error" in result:
            print(f"[{dt.now().strftime('%Y-%m-%d %H:%M:%S')}] 周排班数据请求错误: {result['error']}")
            return jsonify(result), 500
            
        return jsonify(result)
    except Exception as e:
        print(f"[{dt.now().strftime('%Y-%m-%d %H:%M:%S')}] 周排班数据请求异常: {str(e)}")
        return jsonify({"error": f"服务器内部错误: {str(e)}"}), 500

def get_weekly_sales_summary(start_date=None):
    """
    获取指定日期开始七天的销售计划分时段统计
    :param start_date: 开始日期，格式为'YYYY-MM-DD'，如果不指定则使用当前日期
    :return: 包含七天销售计划分时段统计的字典
    """
    # 生成缓存键
    cache_key = f"weekly_sales_summary_{start_date if start_date else 'today'}"
    
    # 尝试从缓存获取数据
    cached_data = cache.get(cache_key)
    if cached_data:
        return cached_data
    
    try:
        # 如果未指定开始日期，则使用当前日期
        if not start_date:
            today = dt.now()
            start_date = today.strftime('%Y-%m-%d')
            
        # 将开始日期转换为datetime对象
        start_datetime = dt.strptime(start_date, '%Y-%m-%d')
        
        # 初始化结果数据结构
        weekly_sales_data = {
            "start_date": start_date,
            "daily_sales_summary": []
        }
        
        # 星期几的中文映射
        weekday_map = {
            0: "星期一",
            1: "星期二",
            2: "星期三",
            3: "星期四",
            4: "星期五",
            5: "星期六",
            6: "星期日"
        }
        
        # 准备一周的日期
        dates = []
        for i in range(7):
            current_date = start_datetime + timedelta(days=i)
            date_str = current_date.strftime('%Y-%m-%d')
            dates.append((date_str, current_date.weekday()))
        
        # 使用线程池并行获取一周内每天的销售数据
        daily_sales_summary = [None] * 7  # 预分配列表空间
        
        def fetch_daily_sales_data(idx, date_info):
            date_str, weekday = date_info
            try:
                # 获取当天的排班数据
                daily_data = get_banbiao_data(date_str)
                
                # 计算分时段销售计划
                sales_plan = daily_data.get("salesPlan", {})
                
                # 计算10:00-17:00销售计划额（10-17点，共8小时，包含17点）
                morning_sales = 0
                for hour in range(10, 18):  # 修改为包含17点
                    hour_str = str(hour)
                    if hour_str in sales_plan:
                        clean_value = str(sales_plan[hour_str]).replace(',', '')
                        morning_sales += int(clean_value) if clean_value.isdigit() else 0
                
                # 计算17:00-20:00销售计划额（18-20点，共3小时，避免与上面重复计算17点）
                evening_sales = 0
                for hour in range(18, 21):  # 修改为18-20点，避免重复计算17点
                    hour_str = str(hour)
                    if hour_str in sales_plan:
                        clean_value = str(sales_plan[hour_str]).replace(',', '')
                        evening_sales += int(clean_value) if clean_value.isdigit() else 0
                
                # 计算总销售计划额
                total_sales = 0
                for hour_str, value in sales_plan.items():
                    clean_value = str(value).replace(',', '')
                    total_sales += int(clean_value) if clean_value.isdigit() else 0
                
                # 添加到结果中
                daily_summary = {
                    "date": date_str,
                    "weekday": weekday_map[weekday],
                    "morning_sales": morning_sales,  # 10:00-17:00
                    "evening_sales": evening_sales,  # 17:00-20:00
                    "total_sales": total_sales,      # 总计
                    "raw_sales_plan": sales_plan     # 原始数据，用于调试
                }
                
                return idx, daily_summary
            except Exception as e:
                return idx, {
                    "date": date_str, 
                    "weekday": weekday_map[weekday], 
                    "morning_sales": 0,
                    "evening_sales": 0,
                    "total_sales": 0,
                    "error": str(e)
                }
        
        # 使用线程池并行处理
        with ThreadPoolExecutor(max_workers=7) as executor:
            # 提交所有任务
            futures = [executor.submit(fetch_daily_sales_data, i, date_info) for i, date_info in enumerate(dates)]
            
            # 收集结果
            for future in futures:
                idx, daily_summary = future.result()
                daily_sales_summary[idx] = daily_summary
        
        # 将结果添加到weekly_sales_data
        weekly_sales_data["daily_sales_summary"] = daily_sales_summary
        
        # 计算周汇总
        total_morning = sum(day["morning_sales"] for day in daily_sales_summary)
        total_evening = sum(day["evening_sales"] for day in daily_sales_summary)
        total_week = sum(day["total_sales"] for day in daily_sales_summary)
        
        weekly_sales_data["weekly_summary"] = {
            "total_morning_sales": total_morning,
            "total_evening_sales": total_evening,
            "total_week_sales": total_week
        }
        
        # 将数据存入缓存
        cache.set(cache_key, weekly_sales_data)
        
        return weekly_sales_data
    except Exception as e:
        return {"error": str(e)}

@app.route('/api/weekly-sales-summary', methods=['GET'])
def api_weekly_sales_summary():
    """
    获取指定日期开始七天的销售计划分时段统计
    请求示例：/api/weekly-sales-summary?start_date=2023-05-01
    参数说明：
    - start_date: 开始日期，格式为'YYYY-MM-DD'（可选，默认为当前日期）
    """
    try:
        start_time = time.time()
        start_date = request.args.get('start_date')
        
        # 记录请求信息
        print(f"[{dt.now().strftime('%Y-%m-%d %H:%M:%S')}] 请求周销售计划统计: start_date={start_date}")
        
        result = get_weekly_sales_summary(start_date)
        
        # 记录响应时间
        elapsed_time = time.time() - start_time
        print(f"[{dt.now().strftime('%Y-%m-%d %H:%M:%S')}] 周销售计划统计请求完成，耗时: {elapsed_time:.2f}秒")
        
        if "error" in result:
            print(f"[{dt.now().strftime('%Y-%m-%d %H:%M:%S')}] 周销售计划统计请求错误: {result['error']}")
            return jsonify(result), 500
            
        return jsonify(result)
    except Exception as e:
        print(f"[{dt.now().strftime('%Y-%m-%d %H:%M:%S')}] 周销售计划统计请求异常: {str(e)}")
        return jsonify({"error": f"服务器内部错误: {str(e)}"}), 500

def get_attendance_data(year_month, staff_name=None, staff_code=None):
    """
    获取员工考勤数据
    :param year_month: 年月，格式为YYYYMM，如202506
    :param staff_name: 员工姓名，可选
    :param staff_code: 员工工号，可选
    :return: 包含考勤数据的字典
    """
    # 生成缓存键
    cache_key = f"attendance_{year_month}_{staff_name}_{staff_code}"
    
    # 尝试从缓存获取数据
    cached_data = cache.get(cache_key)
    if cached_data:
        return cached_data
    
    try:
        # 设置请求超时
        timeout = 15  # 15秒超时，考勤数据可能较多
        
        # 登录获取cookie和session
        cookie, session = login(timeout)
        
        # 获取当前日期，用于请求参数
        today = date.today()
        date_day_ymd = today.strftime('%Y%m%d')
        
        # 解析年月
        year = int(str(year_month)[:4])
        month = int(str(year_month)[4:])
        
        # 构建请求参数
        # URL编码员工姓名和工号
        encoded_name = urllib.parse.quote(staff_name) if staff_name else ''
        encoded_code = staff_code if staff_code else ''
        
        # 构建请求payload
        payload = f"tenpo_Cd=1000059&tenpo_Name=%28%E4%B8%8A%E6%B5%B7%29059_%E5%A2%A8%E7%8E%89%E5%8D%97%E8%B7%AF%E5%BA%97&view_Date={year_month}&shain_Cd={encoded_code}&shain_Nm={encoded_name}&hyoji_Tsuki=&monthly_Jitsudo_Jikan=&monthly_Kyukei_Jikan=&monthly_Zangyo_Jikan=&monthly_Shinya_Jikan=&monthly_ChiSou_Jikan=&monthly_Syukkin=&monthly_Koukyuu=&monthly_Yukyu=&monthly_Kyuusyutu=&monthly_Kihonkyu=0.00&monthly_Zangyo_Teate=0.00&monthly_Shinya_Teate=0.00&runTime=&monthly_Jikantai1_Teate=0.00&combox_DateFrom={date_day_ymd}&combox_DateTo={date_day_ymd}&authorityFlg=1&status=&hyoji_Tsuki=&kakuteiFlg=&disableFlg=&yearMonthFlg=0&authorityAlterFlag=&approvalFlg=&message2=&context_path=%2FTastyQube_SALIYA&url_suffix=.do&list_start_index=&focus_name=&actionId=Review&conditionDisabled=false&hozona=1&shopChangeFlg=false&entryItemEditState=false&searchConditionEditState=true&validtionError=false&screenAppId=D-03-02&screenId=D-03-02&screenName=%E4%B8%AA%E4%BA%BA%E5%AE%9E%E9%99%85%E8%80%83%E5%8B%A4&companyCd=QPRUVM&borwser=Browser%3A+Google+Chrome+119.0.0.0++Ver%3A%5BMozilla%2F5.0+%28Windows+NT+10.0%3B+Win64%3B+x64%29+AppleWebKit%2F537.36+%28KHTML%2C+like+Gecko%29+Chrome%2F119.0.0.0+Safari%2F537.36%5D++OS%3AWindows+10++Language%3A&borwserLng=zh-CN"
        
        # 个人实际考勤请求URL
        url = "https://www1.tastyqube.com.cn/TastyQube_SALIYA/Kt03002Action.do?&fromAppId=D-03-02&companyCd=QPRUVM"
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.102 Mobile Safari/537.36',
            'Accept': '*/*',
            'Host': 'www1.tastyqube.com.cn',
            'Connection': 'keep-alive',
            'Content-Type': 'application/x-www-form-urlencoded',
            'Cookie': cookie
        }
        
        # 发送请求
        response = session.post(url, headers=headers, data=payload, timeout=timeout)
        html_content = response.text
        print(f"考勤数据: {html_content}")
        # 解析HTML
        soup = BeautifulSoup(html_content, 'html.parser')
        right_div = soup.find('div', {'id': 'rightColumn'})
        
        if not right_div:
            return {"error": "无法获取考勤数据"}
        
        # 获取该月的天数
        days_in_month = calendar.monthrange(year, month)[1]
        
        # 定义字段映射，便于维护
        field_mapping = {
            'work_dian': 'kinmu_Tenpo',
            'fact_up_time': 'dakoku_Jisseki1_Syukkin',
            'plan_start_time': 'yotei1_Syukkin',
            'plan_end_time': 'yotei1_Taikin',
            'fact_down_time': 'dakoku_Jisseki1_Taikin',
            'free_start_time': 'kyukei11_Start',
            'free_end_time': 'kyukei11_End',
            'up_change_time': 'dakoku_Syusei1_Syukkin',
            'down_change_time': 'dakoku_Syusei1_Taikin',
            'sure_upwork_time': 'shukkin_Hm_1',
            'sure_downwork_time': 'taikin_Hm_1',
            'work_total_time': 'jitsudo_Jikan',
            'free_total_time': 'kyukei_Jikan',
            'more_work_time': 'zangyo_Jikan'
        }
        
        # 中文字段名映射
        field_names = {
            'work_dian': '勤务门店',
            'fact_up_time': '实际打卡上班时间',
            'plan_start_time': '预定上班时间',
            'plan_end_time': '预定下班时间',
            'fact_down_time': '实际打卡下班时间',
            'free_start_time': '休息开始时间',
            'free_end_time': '休息结束时间',
            'up_change_time': '上班打卡修改时间',
            'down_change_time': '下班打卡修改时间',
            'sure_upwork_time': '确定实际上班时间',
            'sure_downwork_time': '确定实际下班时间',
            'work_total_time': '实勤时间',
            'free_total_time': '休息时间',
            'more_work_time': '加班时间'
        }
        
        # 获取星期几的中文名称
        weekdays = ['一', '二', '三', '四', '五', '六', '日']
        
        # 安全获取字段值的函数
        def safe_get_value(detail_tr, field_name, day_index):
            try:
                input_tag = detail_tr.find('input', {'name': f'detailList[{day_index}].{field_name}'})
                return input_tag.get('value') if input_tag else ''
            except:
                return ''
        
        # 初始化结果数据结构
        result = {
            "year_month": f"{year}年{month}月",
            "staff_name": staff_name,
            "staff_code": staff_code,
            "daily_attendance": [],
            "total_work_time": ""
        }
        
        # 遍历每一天
        for day in range(1, days_in_month + 1):
            day_index = day - 1  # 从0开始的索引
            
            # 创建日期对象获取星期
            date_obj = datetime.datetime(year, month, day)
            weekday = weekdays[date_obj.weekday()]
            
            # 查找对应的详情行
            detail_tr = right_div.find('tr', {'id': f'detail{day_index}'})
            
            if not detail_tr:
                # 如果找不到数据，添加空记录
                result["daily_attendance"].append({
                    "date": f"{year}-{month:02d}-{day:02d}",
                    "weekday": f"星期{weekday}",
                    "has_data": False,
                    "message": "无考勤数据"
                })
                continue
            
            # 获取所有字段数据
            daily_data = {
                "date": f"{year}-{month:02d}-{day:02d}",
                "weekday": f"星期{weekday}",
                "has_data": False,
                "attendance": {}
            }
            
            # 获取并添加所有字段数据
            for field_key, field_name in field_mapping.items():
                value = safe_get_value(detail_tr, field_name, day_index)
                if value:  # 只添加有值的字段
                    daily_data["attendance"][field_key] = value
                    daily_data["attendance"][field_key + "_label"] = field_names[field_key]
                    daily_data["has_data"] = True
            
            # 添加到结果中
            result["daily_attendance"].append(daily_data)
        
        # 获取总工时
        total_work_time_input = soup.find('input', {'name': 'monthly_Jitsudo_Jikan'})
        if total_work_time_input:
            result["total_work_time"] = total_work_time_input.get('value', '')
        
        # 将数据存入缓存
        cache.set(cache_key, result)
        
        return result
    except requests.exceptions.Timeout:
        return {"error": "请求超时，请稍后重试"}
    except requests.exceptions.ConnectionError:
        return {"error": "连接错误，请检查网络"}
    except Exception as e:
        return {"error": str(e)}

@app.route('/api/attendance', methods=['GET'])
def get_attendance():
    """
    获取员工考勤数据
    请求示例：/api/attendance?year_month=202506&name=张三&code=1001
    参数说明：
    - year_month: 年月，格式为YYYYMM，如202506（必填）
    - name: 员工姓名（可选）
    - code: 员工工号（可选）
    注意：name和code至少需要提供一个
    """
    try:
        start_time = time.time()
        
        # 获取请求参数
        year_month = request.args.get('year_month')
        staff_name = request.args.get('name')
        staff_code = request.args.get('code')
        
        # 验证参数
        if not year_month:
            return jsonify({"error": "请提供年月参数 'year_month'，格式为YYYYMM，如202506"}), 400
        
        if not staff_name and not staff_code:
            return jsonify({"error": "请提供员工姓名参数 'name' 或工号参数 'code'"}), 400
        
        # 记录请求信息
        print(f"[{dt.now().strftime('%Y-%m-%d %H:%M:%S')}] 请求考勤数据: year_month={year_month}, name={staff_name}, code={staff_code}")
        
        # 获取考勤数据
        result = get_attendance_data(year_month, staff_name, staff_code)
        
        # 记录响应时间
        elapsed_time = time.time() - start_time
        print(f"[{dt.now().strftime('%Y-%m-%d %H:%M:%S')}] 考勤数据请求完成，耗时: {elapsed_time:.2f}秒")
        
        if "error" in result:
            print(f"[{dt.now().strftime('%Y-%m-%d %H:%M:%S')}] 考勤数据请求错误: {result['error']}")
            return jsonify(result), 500
            
        return jsonify(result)
    except Exception as e:
        print(f"[{dt.now().strftime('%Y-%m-%d %H:%M:%S')}] 考勤数据请求异常: {str(e)}")
        return jsonify({"error": f"服务器内部错误: {str(e)}"}), 500

@app.route('/')
def index():
    return app.send_static_file('index.html')

# 营业额API接口
@app.route('/api/revenue', methods=['GET'])
def api_revenue():
    try:
        revenue_data = get_revenue()
        return jsonify({
            'success': True,
            'revenue': revenue_data,
            'timestamp': dt.now().strftime('%Y-%m-%d %H:%M:%S')
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
