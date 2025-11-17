from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS  # 导入 CORS
import requests
import time
import json
from bs4 import BeautifulSoup
import datetime
from urllib.parse import quote
import openai
# 以下依赖仅在某些功能下使用，为避免启动失败先注释
# from langchain_openai import ChatOpenAI
# from langchain_core.messages import SystemMessage, HumanMessage

app = Flask(__name__)
CORS(app)  # 启用 CORS

# 读取配置
with open('config.json', encoding='utf-8') as config_file:  # 指定编码为 utf-8
    config = json.load(config_file)

openai_api_key = config['api_key']
api_base_url = config['api_base_url']
current_prompt = config['prompt']
current_model = config["model_name"]

# 初始化 ChatOpenAI
# chat = ChatOpenAI(
#     model="gpt-4o",
#     openai_api_key=config['api_key'],
#     openai_api_base=config['api_base_url']
# )

def banbiao(json_data):
    try:
        print(f"json_data: {json_data}")
        
        # 设置目标网址
        url = "https://www1.tastyqube.com.cn/TastyQube_SALIYA/LoginAction.do?fromAppId=H-01-01&companyCd=QPRUVM"

        # 创建一个会话对象，自动管理 cookies
        payload = 'loginId=1S00059&password=1S0000059&companyCd=QPRUVM&companyCd=QPRUVM&borwser=Browser%3A%20Google%20Chrome%2098.0.4758.102%20%20Ver%3A%5BMozilla%2F5.0%20(Windows%20NT%2010.0%3B%20Win64%3B%20x64)%20AppleWebKit%2F537.36%20(KHTML&borwser=null&borwserLng=zh-CN&borwserLng=null&context_path=%2FTastyQube_SALIYA&url_suffix=.do&list_start_index=&focus_name=&actionId=&conditionDisabled=true&hozona=&shopChangeFlg=false&entryItemEditState=true&searchConditionEditState=false&validtionError=false&screenAppId=H-01-01&screenId=H-01-01&screenName=LOGIN%E7%94%BB%E9%9D%A2'
        headers = {
            'Accept': '*/*',
            'Host': 'www1.tastyqube.com.cn',
            'Connection': 'keep-alive',
            'Content-Type': 'application/x-www-form-urlencoded'
        }
        session = requests.session()
        response = session.post(url, headers=headers, data=payload)

        # 获取并打印 cookies
        cookies = response.cookies

        cookie_name = ''
        cookie_value = ''

        # 打印 cookies 信息，并提取需要的 cookie
        for cookie in cookies:
            cookie_name = cookie.name
            cookie_value = cookie.value
            print(f"Cookie Name: {cookie.name}, Cookie Value: {cookie.value}")

        # 生成 cookie 字符串
        cookie = f'{cookie_name}={cookie_value}'
        print(f"Cookie for future requests: {cookie}")

        # 设置第二个请求的 URL 和数据
        url2 = "https://www1.tastyqube.com.cn/TastyQube_SALIYA/Kt01001SHAction.do?fromAppId=D-01-01_SH&companyCd=QPRUVM"

        # 构建请求的 payload
        # 获取当前日期
        today = datetime.date.today()
        print(today)
        # 获取下一个星期的开始和结束日期
        # 假设周一是每周的第一天，计算下一个星期的开始和结束日期
        monday_next_week = today + datetime.timedelta(days=(7 - today.weekday()))  # 下个星期一
        sunday_next_week = monday_next_week + datetime.timedelta(days=6)  # 下个星期天

        # 格式化为需要的格式
        date_week_mon_week = f"{monday_next_week.strftime('%Y/%m/%d')},{sunday_next_week.strftime('%Y/%m/%d')}"

        # 其他日期参数
        date_day_ymd = today.strftime('%Y%m%d')
        date_week_year_mon = today.strftime('%Y/%m')
        date_period_ymd_from = date_day_ymd
        date_period_ymd_to = date_day_ymd
        view_date_from = date_day_ymd
        view_date_to = date_day_ymd

        # 构建动态生成的payload
        payload = f"tenpo_Cd=1000059&tenpo_Name=%28%E4%B8%8A%E6%B5%B7%29059_%E5%A2%A8%E7%8E%89%E5%8D%97%E8%B7%AF%E5%BA%97&selDate=1&dateDayYmd={quote(date_day_ymd)}&dateWeekYearMon={quote(date_week_year_mon)}&dateWeekMonWeek={quote(date_week_mon_week)}&dateWeekYmdFrom={quote(monday_next_week.strftime('%Y%m%d'))}&dateWeekYmdTo={quote(sunday_next_week.strftime('%Y%m%d'))}&dateMonthYm={quote(date_week_year_mon)}&datePeriodYmdFrom={quote(date_period_ymd_from)}&datePeriodYmdTo={quote(date_period_ymd_to)}&sort=3&date1=&weekday1=&background_Color1=&date2=&weekday2=&background_Color2=&date3=&weekday3=&background_Color3=&date4=&weekday4=&background_Color4=&date5=&weekday5=&background_Color5=&date6=&weekday6=&background_Color6=&date7=&weekday7=&background_Color7=&conditionDisabled=false&initFlg=1&eventFlg=1&sort=3&detailCount=&focusField=&message1=&editFlg1=false&editFlg2=false&editFlg3=false&editFlg4=false&editFlg5=false&editFlg6=false&editFlg7=false&view_Date={quote(view_date_from)}&dateWeekMonWeekHidden={quote(date_week_mon_week)}&view_DateFrom={quote(view_date_from)}&view_DateTo={quote(view_date_to)}&dateItemMonthWeek=%E6%9C%88%2C%E5%91%A8&messageDelStr=%E5%88%A0%E9%99%A4%E8%AF%A5%E8%AE%B0%E5%BD%95%E3%80%82+%E6%98%AF%E5%90%A6%E7%BB%A7%E7%BB%AD%EF%BC%9F&editFlg=&weekNum=1&allDisable=&copyStartDay=&copyMsgStr=&context_path=%2FTastyQube_SALIYA&url_suffix=.do&list_start_index=&focus_name=selDate&actionId=Review&conditionDisabled=false&hozona=1&shopChangeFlg=false&entryItemEditState=false&searchConditionEditState=true&validtionError=false&screenAppId=D-01-01_SH&screenId=D-01-01_SH&screenName=%E6%9C%9F%E9%97%B4%E6%9C%9F%E6%9C%9B%E6%97%A5%E7%A8%8B%E7%99%BB%E5%BD%95&companyCd=QPRUVM&borwser=Browser%3A+Google+Chrome+98.0.4758.102++Ver%3A%5BMozilla%2F5.0+%28Windows+NT+10.0%3B+Win64%3B+x64%29+AppleWebKit%2F537.36+%28KHTML%2C+like+Gecko%29+Chrome%2F98.0.4758.102+Safari%2F537.36%5D++OS%3AWindows+10++Language%3A&borwserLng=zh-CN"

        headers = {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.102 Mobile Safari/537.36',
            'Accept': '*/*',
            'Host': 'www1.tastyqube.com.cn',
            'Connection': 'keep-alive',
            'Content-Type': 'application/x-www-form-urlencoded',
            'Cookie': cookie
        }

        # 使用 session 发起 POST 请求
        response2 = session.post(url2, headers=headers, data=payload)
        # 打印响应内容
        html_content = response2.text
        #print(html_content)
        # 解析 HTML
        soup = BeautifulSoup(html_content, 'html.parser')
        #print(soup)
        report_div = soup.find('div', {'id': 'content_part'})
        if report_div:
            table_div = report_div.find('div', {'id': 'table_2'})
            if table_div:
                trs = table_div.find_all("tr")  # 获取所有<tr>

                # 获取第二个<tr>（索引为1）
                if len(trs) > 1:
                    peo_tr = trs[3]
                    peo_td = peo_tr.find("td")
                    len_tr = len(peo_td.find_all("tr"))
                    i = 0

                    all_data = {}

                    while i < len_tr:
                        input_elems = peo_td.find('tr', {'id': f'detail{i}'})

                        if input_elems:
                            # 获取第一个input元素的value作为标识符
                            first_input = input_elems.find('input')
                            if first_input:
                                identifier = first_input.get('value', '无标识')  # 获取第一个input的value作为标识

                                # 存储与该标识相关的数据
                                input_data = {}

                                # 遍历所有的input元素
                                inputs = input_elems.find_all("input")
                                for input_elem in inputs:
                                    name = input_elem.get('name', '')  # 获取name属性，若没有则返回'无name'
                                    value = input_elem.get('value', '')  # 获取value属性，若没有则返回'无value'
                                    if len(value) == 5:
                                        value = value.replace(":", "")
                                    input_data[name] = value  # 将name和value存储为字典的键值对

                                # 将该标识符和对应的数据存入all_data字典
                                all_data[identifier] = input_data

                                # 打印出当前标识符下的所有输入数据
                                # print(f"标识符: {identifier}")
                                # for name, value in input_data.items():
                                #     print(f"  name: {name}, value: {value}")
                            else:
                                print(f"没有找到id为detail{i}的第一个input元素")
                        else:
                            print(f"没有找到id为detail{i}的tr标签")

                        i += 1

                    # target_identifier = '楼炜'  # 需要修改的identifier
                    # target_name = 'detailList[28].startTime1'  # 需要修改的name
                    # new_value = '1100'  # 要设置的新value
                    #
                    # # 查找并修改指定标识符下对应的name的value
                    # if target_identifier in all_data:
                    #     input_data = all_data[target_identifier]  # 获取该标识符下的所有数据
                    #
                    #     if target_name in input_data:
                    #         # 修改value值
                    #         input_data[target_name] = new_value
                    #         print(f"已修改 {target_identifier} 下 {target_name} 的 value 为: {new_value}")
                    #     else:
                    #         print(f"在 {target_identifier} 下没有找到 {target_name}")
                    # else:
                    #     print(f"没有找到标识符")

                    #打印最终存储的所有数据
                    # for identifier, input_data in all_data.items():
                    #     for index, (name, value) in enumerate(input_data.items()):
                    #         # 只处理从第三个 (index 2) 到第十七个 (index 16) 的元素
                    #         if 2 <= index <= 16:
                    #             print(f"  name: {name}, value: {value}")
                    # 定义特殊员工列表
                    special_employees = ['廖永伟', '刘燕', '赵金星', '王杰', '邵怡', '楼炜']

                    for identifier, input_data in all_data.items():
                        # 先检查是否为特殊员工
                        is_special = identifier in special_employees
                        
                        for index, (name, value) in enumerate(input_data.items()):
                            if 2 <= index < 16:  # 只处理从第三个到第十七个元素
                                time_key = name.split('.')[-1]
                                if is_special:
                                    # 特定员工设置固定时间
                                    if 'startTime' in time_key:
                                        input_data[name] = '1100'
                                    elif 'endTime' in time_key:
                                        input_data[name] = '2200'
                                elif identifier in json_data:
                                    # 其他员工且在json_data中存在的情况
                                    input_data[name] = json_data[identifier].get(time_key, '')
                                else:
                                    # 不在json_data中的情况
                                    input_data[name] = ''

                    for identifier, input_data in all_data.items():
                        print(f'标识符:{identifier}')
                        for index, (name, value) in enumerate(input_data.items()):
                            if 2 <= index <= 16:
                                print(f"  name: {name}, value: {value}")

                    #time.sleep(1000000)
                    # 在这里发起新的请求
                    # 设置第二个请求的 URL 和数据
                    url3 = "https://www1.tastyqube.com.cn/TastyQube_SALIYA/Kt01001SHAction.do?fromAppId=D-01-01_SH&companyCd=QPRUVM"

                    # 计算下一个星期的日期
                    days_of_week = ['(一)', '(二)', '(三)', '(四)', '(五)', '(六)', '(日)']
                    background_colors = ['bgGray', 'bgGray', 'bgGray', 'bgGray', 'bgGray', 'bgSkyBlue', 'bgPink']

                    # 创建一个字典，用于存储日期、星期、背景颜色
                    next_week_data = {}

                    # 获取下一个星期的日期
                    for i in range(7):
                        next_date = today + datetime.timedelta(days=(7 - today.weekday() + i) % 7)  # 计算下一个星期对应的日期
                        next_date_str = next_date.strftime('%m/%d')  # 格式化为 MM/DD
                        next_week_data[f'date{i + 1}'] = next_date_str
                        next_week_data[f'weekday{i + 1}'] = days_of_week[i]
                        next_week_data[f'background_Color{i + 1}'] = background_colors[i]

                    # # 构建新的payload
                    payload = {
                        'tenpo_Cd': '1000059',
                        'tenpo_Name': '(上海)059_墨玉南路店',
                        'selDate': '1',
                        'dateDayYmd': date_day_ymd,
                        'dateWeekYearMon': date_week_year_mon,
                        'dateWeekMonWeek': date_week_mon_week,
                        'dateWeekYmdFrom': monday_next_week.strftime('%Y%m%d'),
                        'dateWeekYmdTo': sunday_next_week.strftime('%Y%m%d'),
                        'dateMonthYm': date_week_year_mon,
                        'datePeriodYmdFrom': date_period_ymd_from,
                        'datePeriodYmdTo': date_period_ymd_to,
                        'sort': '3',
                        'tenpo_Cd': '1000059',
                        'tenpo_Name': '(上海)059_墨玉南路店',
                        'selDate': '1',
                        'dateDayYmd': date_day_ymd,
                        'dateWeekYearMon': date_week_year_mon,
                        'dateWeekMonWeek': date_week_mon_week,
                        'dateWeekYmdFrom': monday_next_week.strftime('%Y%m%d'),
                        'dateWeekYmdTo': sunday_next_week.strftime('%Y%m%d'),
                        'dateMonthYm': date_week_year_mon,
                        'datePeriodYmdFrom': date_period_ymd_from,
                        'datePeriodYmdTo': date_period_ymd_to,
                        'sort': '3',
                        # 动态拼接 all_data 中的参数
                        **{f"{name}": value for identifier, input_data in all_data.items() for name, value in input_data.items()},
                        'conditionDisabled': 'true',
                        'initFlg': '0',
                        'eventFlg': '0',
                        'detailCount': '29',
                        'focusField': 'detailList[28].endTime1',
                        'message1': '请选择上班时间或下班时间输入框。',
                        'editFlg1': 'false',
                        'editFlg2': 'false',
                        'editFlg3': 'false',
                        'editFlg4': 'false',
                        'editFlg5': 'false',
                        'editFlg6': 'false',
                        'editFlg7': 'false',
                        'view_Date': monday_next_week.strftime('%Y%m%d'),
                        'dateWeekMonWeekHidden': date_week_mon_week,
                        'view_DateFrom': monday_next_week.strftime('%Y%m%d'),
                        'view_DateTo': sunday_next_week.strftime('%Y%m%d'),
                        'dateItemMonthWeek': '月,周',
                        'messageDelStr': '删除该记录。 是否继续？',
                        'editFlg': '0',
                        'weekNum': '1',
                        'allDisable': '0',
                        'copyStartDay': date_day_ymd,
                        'copyMsgStr': '复制期间内，数据会清除,是否继续?',
                        'context_path': '/TastyQube_SALIYA',
                        'url_suffix': '.do',
                        'list_start_index': '',
                        'focus_name': '',
                        'actionId': 'Entry.DB',
                        'hozona': '1',
                        'shopChangeFlg': 'false',
                        'entryItemEditState': 'true',
                        'searchConditionEditState': 'false',
                        'validtionError': 'false',
                        'screenAppId': 'D-01-01_SH',
                        'screenId': 'D-01-01_SH',
                        'screenName': '期间期望日程登录',
                        'companyCd': 'QPRUVM',
                        'borwser': 'Browser: Google Chrome 98.0.4758.102  Ver:[Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.102 Safari/537.36]  OS:Windows 10  Language:',
                        'borwserLng': 'zh-CN'
                    }
                    payload.update(next_week_data)
                    # 在发送最后的请求之前
                    print("正在提交排班数据...")
                    response3 = session.post(url3, headers=headers, data=payload)
                    print(response3.text)
                    if response3.text:
                        return {"success": True, "message": "排班数据提交成功"}
                    else:
                        return {"success": False, "message": "排班数据提交可能失败，请检查系统"}
                    # 检查响应状态
                else:
                    print("没有足够的<tr>元素")

    except Exception as e:
        print(f"排班过程中发生错误: {str(e)}")
        return {"success": False, "message": f"发生错误：{str(e)}"}

# ----------------------- 商品销售数据接口 -----------------------
def _login_for_products():
    url = "https://www1.tastyqube.com.cn/TastyQube_SALIYA/LoginAction.do?fromAppId=H-01-01&companyCd=QPRUVM"
    payload = 'loginId=1S00059&password=1S0000059&companyCd=QPRUVM&companyCd=QPRUVM&borwser=Browser%3A%20Google%20Chrome%2098.0.4758.102%20%20Ver%3A%5BMozilla%2F5.0%20(Windows%20NT%2010.0%3B%20Win64%3B%20x64)%20AppleWebKit%2F537.36%20(KHTML&borwser=null&borwserLng=zh-CN&borwserLng=null&context_path=%2FTastyQube_SALIYA&url_suffix=.do&list_start_index=&focus_name=&actionId=&conditionDisabled=true&hozona=&shopChangeFlg=false&entryItemEditState=true&searchConditionEditState=false&validtionError=false&screenAppId=H-01-01&screenId=H-01-01&screenName=LOGIN%E7%94%BB%E9%9D%A2'
    headers = {
        'Accept': '*/*',
        'Host': 'www1.tastyqube.com.cn',
        'Connection': 'keep-alive',
        'Content-Type': 'application/x-www-form-urlencoded'
    }
    session = requests.session()
    response = session.post(url, headers=headers, data=payload)
    cookies = response.cookies
    cookie_name = ''
    cookie_value = ''
    for c in cookies:
        cookie_name = c.name
        cookie_value = c.value
    cookie = f'{cookie_name}={cookie_value}'
    return cookie, session

def _get_dynamic_dates(custom_start_date=None, custom_end_date=None, chooseData=None):
    if chooseData:
        today = datetime.datetime.strptime(chooseData, "%Y%m%d")
    else:
        today = datetime.datetime.today()
    dateDayYmd = today.strftime("%Y%m%d")
    dateWeekYearMon = today.strftime("%Y%m")
    dateMonthYm = today.strftime("%Y%m")
    datePeriodYmdTo = (today - datetime.timedelta(days=1)).strftime("%Y%m%d")
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

def _build_request(newplay: str, dv: dict):
    newplay = newplay.replace('dateDayYmd=20250807', f'dateDayYmd={dv["dateDayYmd"]}')
    newplay = newplay.replace('dateWeekYearMon=202508', f'dateWeekYearMon={dv["dateWeekYearMon"]}')
    newplay = newplay.replace('dateWeekMonWeek=2025%2F08%2F04%2C2025%2F08%2F10', f'dateWeekMonWeek={dv["dateWeekMonWeek"]}')
    newplay = newplay.replace('dateWeekYmdFrom=20250804', f'dateWeekYmdFrom={dv["dateWeekYmdFrom"]}')
    newplay = newplay.replace('dateWeekYmdTo=20250810', f'dateWeekYmdTo={dv["dateWeekYmdTo"]}')
    newplay = newplay.replace('dateMonthYm=202508', f'dateMonthYm={dv["dateMonthYm"]}')
    newplay = newplay.replace('datePeriodYmdFrom=20250801', f'datePeriodYmdFrom={dv["datePeriodYmdFrom"]}')
    newplay = newplay.replace('datePeriodYmdTo=20250806', f'datePeriodYmdTo={dv["datePeriodYmdTo"]}')
    return newplay

@app.route('/api/products', methods=['POST'])
def api_products():
    try:
        payload_in = request.json or {}
        seldate = int(payload_in.get('seldate', 0))
        chooseData = payload_in.get('chooseData')  # yyyymmdd
        custom_start_date = payload_in.get('custom_start_date')
        custom_end_date = payload_in.get('custom_end_date')

        cookie, session = _login_for_products()
        dv = _get_dynamic_dates(custom_start_date, custom_end_date, chooseData)

        newplay = (
            f"tenpo_Cd=1000059&tenpo_Name=%28%E4%B8%8A%E6%B5%B7%29059_%E5%A2%A8%E7%8E%89%E5%8D%97%E8%B7%AF%E5%BA%97&selDate={seldate}"
            f"&dateDayYmd=20250807&dateWeekYearMon=202508&dateWeekMonWeek=2025%2F08%2F04%2C2025%2F08%2F10&dateWeekYmdFrom=20250804&dateWeekYmdTo=20250810&dateMonthYm=202508&datePeriodYmdFrom=20250801&datePeriodYmdTo=20250806"
            f"&dateDayYmd=2025%2F08%2F07&dateWeekYearMon=2025%2F08&dateMonthYm=2025%2F08&datePeriodYmdFrom=2025%2F08%2F01&datePeriodYmdTo=2025%2F08%2F06"
            f"&monday=1&tuesday=1&wednesday=1&thursday=1&friday=1&saturday=1&sunday=1&specialDay=1&furikaeDay=1&weather=&productSetFlg=0&dbumon=1&cbumon=1&sbumon=1&menu_no=1&kubun_flg=1&unshowZeroFlag=1&bunrui=&sort=0&salesType=&unshowwaster=1&popFlag=false&productSetDisFlg=1&salesTypeDisFlg=1&authorityFlg=1&msg=&wasteName=H%E6%97%A0%E7%94%A8%E6%B6%88%E8%80%97&wasteSize="
            f"&dateWeekMonWeekHidden=2025%2F08%2F07&view_DateFrom=2025%2F08%2F01&view_DateTo=2025%2F08%2F06&dateItemMonthWeek=%E6%9C%88%2C%E5%91%A8&strTenpoCd=1000059&strTenpoNm=&strTenpoKbn=+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+&information=&context_path=%2FTastyQube_SALIYA&url_suffix=.do&list_start_index=&focus_name=selDate&actionId=Review&conditionDisabled=false&hozona=1&shopChangeFlg=false&entryItemEditState=false&searchConditionEditState=false&validtionError=false&screenAppId=C-03-36&screenId=C-03-36&screenName=%E5%95%86%E5%93%81%E9%94%80%E5%94%AE%E5%88%86%E6%9E%90&companyCd=QPRUVM&borwser=Browser%3A+Google+Chrome+119.0.0.0++Ver%3A%5BMozilla%2F5.0+%28Windows+NT+10.0%3B+Win64%3B+x64%29+AppleWebKit%2F537.36+%28KHTML%2C+like+Gecko%29+Chrome%2F119.0.0.0+Safari%2F537.36%5D++OS%3AWindows+10++Language%3A&borwserLng=zh-CN"
        )
        newplay = _build_request(newplay, dv)

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
        current_id = None
        current_name = None
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
                    # 商品编号 + 商品名 行
                    if len(tds) >= 2:
                        current_id = tds[0].get_text(strip=True)
                        current_name = tds[1].get_text(strip=True)
                    continue
                # 明细行，读取需要字段
                price = tds[0].get_text(strip=True) if len(tds) > 0 else ""
                sales_number = tds[3].get_text(strip=True) if len(tds) > 3 else ""
                avg_sales_per_day = tds[5].get_text(strip=True) if len(tds) > 5 else ""

                # 收集扩展字段作为详情
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
                    products.append({
                        'product_id': current_id,
                        'product_name': current_name,
                        'price': price,
                        'sales_number': sales_number,
                        'avg_sales_per_day': avg_sales_per_day,
                        'details': details
                    })
                    current_id, current_name = None, None
            i += 1

        return jsonify({"data": products})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# 前端页面路由（直接返回静态文件）
@app.route('/product-sales')
def product_sales_page():
    return send_from_directory('.', '商品销售.html')

@app.route('/api/recognize', methods=['POST'])
def recognize():
    try:
        # 获取输入数据
        data = request.json.get('data')
        if not data:
            return jsonify({"error": "未提供数据"}), 400


        payload = json.dumps({
            "model": current_model,
            "messages": [
                {
                    "role": "system",
                    "content": "请根据以下规则识别员工报班情况并返回 JSON 格式的数据：\n1. 全天上班默认时间为 11:00-22:00，不允许出现 9:00-22:00。\n2. 店铺开门时间为 9:00，关门时间为 22:00。\n3. 返回格式示例：\n{\n员工姓名\": {\n\"startTime1\": \"0900\",\n\"endTime1\": \"2200\"\n}\n}\n4.日期映射关系为星期一上班时间表示为startTime1，下班时间表示为endTime1，后续星期依次类推 \n5. 没有报班的日期不需要显示。\n6. 只返回 JSON 数据，不需要其他解释。\n"
                },
                {
                    "role": "user",
                    "content": f"{data}"
                }
            ],
            "stream": False,
            "temperature": 1,
            "top_p": 1
        })
        headers = {
            'User-Agent': 'Apifox/1.0.0 (https://apifox.com)',
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {openai_api_key}',
            'Accept': '*/*',
            'Host': 'api.gptgod.online',
            'Connection': 'keep-alive'
        }

        response = requests.request("POST", api_base_url, headers=headers, data=payload)
        response_json = response.json()  # 将响应内容解析为 JSON 格式

        # 获取 choices 中 message 中 content 内容
        content = response_json["choices"][0]["message"]["content"]
        print(content)

        # 清理并解析返回的数据
        result_data = content.strip()
        if result_data.startswith("```json"):
            result_data = result_data.split("```json")[1]
        if result_data.startswith("```"):
            result_data = result_data.split("```")[1]
        if result_data.endswith("```"):
            result_data = result_data[:-3]

        result_data = result_data.strip()
        json_data = json.loads(result_data)
        
        
        return jsonify(json_data)

    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/confirm', methods=['POST'])
def confirm():
    try:
        json_data = request.json
        if not json_data:
            return jsonify({"error": "未提供数据"}), 400

        # 调用 banbiao 函数处理数据并等待结果
        result = banbiao(json_data)
        
        # 根据 banbiao 函数的返回结果返回响应
        if result["success"]:
            return jsonify({"success": True, "message": result["message"]})
        else:
            return jsonify({"error": result["message"]}), 500

    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True)