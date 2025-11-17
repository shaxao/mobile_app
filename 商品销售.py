import requests
from bs4 import BeautifulSoup
from datetime import datetime,date,  timedelta
import calendar
import re

def login():
    url = "https://www1.tastyqube.com.cn/TastyQube_SALIYA/LoginAction.do?fromAppId=H-01-01&companyCd=QPRUVM"

    # 创建一个会话对象，自动管理 cookies
    payload = 'loginId=1S00059&password=S1000059&companyCd=QPRUVM&companyCd=QPRUVM&borwser=Browser%3A%20Google%20Chrome%2098.0.4758.102%20%20Ver%3A%5BMozilla%2F5.0%20(Windows%20NT%2010.0%3B%20Win64%3B%20x64)%20AppleWebKit%2F537.36%20(KHTML&borwser=null&borwserLng=zh-CN&borwserLng=null&context_path=%2FTastyQube_SALIYA&url_suffix=.do&list_start_index=&focus_name=&actionId=&conditionDisabled=true&hozona=&shopChangeFlg=false&entryItemEditState=true&searchConditionEditState=false&validtionError=false&screenAppId=H-01-01&screenId=H-01-01&screenName=LOGIN%E7%94%BB%E9%9D%A2'
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
    return cookie,session
# 获取当前日期、月份及相关时间
def get_dynamic_dates(custom_start_date=None, custom_end_date=None, chooseData=None):
    # 获取当前日期
    if chooseData:
        today = datetime.strptime(chooseData, "%Y%m%d")
    else:
        today = datetime.today()

    # 当前日期：dateDayYmd
    dateDayYmd = today.strftime("%Y%m%d")

    # 当前月份：dateWeekYearMon 和 dateMonthYm
    dateWeekYearMon = today.strftime("%Y%m")
    dateMonthYm = today.strftime("%Y%m")

    # 昨天的日期：datePeriodYmdTo
    datePeriodYmdTo = (today - timedelta(days=1)).strftime("%Y%m%d")

    # 本月的开始日期：datePeriodYmdFrom
    datePeriodYmdFrom = today.replace(day=1).strftime("%Y%m%d")

    # 手动选择的日期起始和终止日期
    if custom_start_date and custom_end_date:
        dateWeekMonWeek = f"{custom_start_date},{custom_end_date}"
        dateWeekYmdFrom = custom_start_date
        dateWeekYmdTo = custom_end_date
    else:
        # 默认使用本月的起始和终止日期
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


# 构建请求参数，替换日期动态值
def build_request(newplay, date_values):
    # 使用传递的日期动态值替换模板中的日期占位符
    newplay = newplay.replace('dateDayYmd=20250807', f'dateDayYmd={date_values["dateDayYmd"]}')
    newplay = newplay.replace('dateWeekYearMon=202508', f'dateWeekYearMon={date_values["dateWeekYearMon"]}')
    newplay = newplay.replace('dateWeekMonWeek=2025%2F08%2F04%2C2025%2F08%2F10',
                              f'dateWeekMonWeek={date_values["dateWeekMonWeek"]}')
    newplay = newplay.replace('dateWeekYmdFrom=20250804', f'dateWeekYmdFrom={date_values["dateWeekYmdFrom"]}')
    newplay = newplay.replace('dateWeekYmdTo=20250810', f'dateWeekYmdTo={date_values["dateWeekYmdTo"]}')
    newplay = newplay.replace('dateMonthYm=202508', f'dateMonthYm={date_values["dateMonthYm"]}')
    newplay = newplay.replace('datePeriodYmdFrom=20250801', f'datePeriodYmdFrom={date_values["datePeriodYmdFrom"]}')
    newplay = newplay.replace('datePeriodYmdTo=20250806', f'datePeriodYmdTo={date_values["datePeriodYmdTo"]}')

    return newplay



def getProduct(custom_start_date=None, custom_end_date=None, seldate=0, chooseData=None):
    cookie, session = login()

    date_values = get_dynamic_dates(custom_start_date, custom_end_date, chooseData)

    # 示例的固定字符串
    newplay = f"tenpo_Cd=1000059&tenpo_Name=%28%E4%B8%8A%E6%B5%B7%29059_%E5%A2%A8%E7%8E%89%E5%8D%97%E8%B7%AF%E5%BA%97&selDate={seldate}&dateDayYmd=20250807&dateWeekYearMon=202508&dateWeekMonWeek=2025%2F08%2F04%2C2025%2F08%2F10&dateWeekYmdFrom=20250804&dateWeekYmdTo=20250810&dateMonthYm=202508&datePeriodYmdFrom=20250801&datePeriodYmdTo=20250806&dateDayYmd=2025%2F08%2F07&dateWeekYearMon=2025%2F08&dateMonthYm=2025%2F08&datePeriodYmdFrom=2025%2F08%2F01&datePeriodYmdTo=2025%2F08%2F06&monday=1&tuesday=1&wednesday=1&thursday=1&friday=1&saturday=1&sunday=1&specialDay=1&furikaeDay=1&weather=&productSetFlg=0&dbumon=1&cbumon=1&sbumon=1&menu_no=1&kubun_flg=1&unshowZeroFlag=1&bunrui=&sort=0&salesType=&unshowwaster=1&popFlag=false&productSetDisFlg=1&salesTypeDisFlg=1&authorityFlg=1&msg=&wasteName=H%E6%97%A0%E7%94%A8%E6%B6%88%E8%80%97&wasteSize=&dateWeekMonWeekHidden=2025%2F08%2F07&view_DateFrom=2025%2F08%2F01&view_DateTo=2025%2F08%2F06&dateItemMonthWeek=%E6%9C%88%2C%E5%91%A8&strTenpoCd=1000059&strTenpoNm=&strTenpoKbn=+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+%2C+&information=&context_path=%2FTastyQube_SALIYA&url_suffix=.do&list_start_index=&focus_name=selDate&actionId=Review&conditionDisabled=false&hozona=1&shopChangeFlg=false&entryItemEditState=false&searchConditionEditState=false&validtionError=false&screenAppId=C-03-36&screenId=C-03-36&screenName=%E5%95%86%E5%93%81%E9%94%80%E5%94%AE%E5%88%86%E6%9E%90&companyCd=QPRUVM&borwser=Browser%3A+Google+Chrome+119.0.0.0++Ver%3A%5BMozilla%2F5.0+%28Windows+NT+10.0%3B+Win64%3B+x64%29+AppleWebKit%2F537.36+%28KHTML%2C+like+Gecko%29+Chrome%2F119.0.0.0+Safari%2F537.36%5D++OS%3AWindows+10++Language%3A&borwserLng=zh-CN"

    # 替换字符串中的日期占位符
    newplay = build_request(newplay, date_values)
    # 个人实际考勤请求
    url3 = "https://www1.tastyqube.com.cn/TastyQube_SALIYA/Ur03036Action.do?fromAppId=C-03-36&companyCd=QPRUVM"

    headers = {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.102 Mobile Safari/537.36',
        'Accept': '*/*',
        'Host': 'www1.tastyqube.com.cn',
        'Connection': 'keep-alive',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cookie': cookie
    }

    # 使用 session 发起 POST 请求
    response2 = session.post(url3, headers=headers, data=newplay)
    # 打印响应内容
    html_content = response2.text
    # print(html_content)
    soup = BeautifulSoup(html_content, 'html.parser')
    i = 4
    while True:
        # 查找对应的商品行
        product_more = soup.find_all('tr', {'id': f'detail{i}'})

        # 如果没有找到任何匹配的 tr 标签，退出循环
        if not product_more:
            print(i)
            i += 1
            if not soup.find_all('tr', {'id': f'detail{i+1}'}):
                if not soup.find_all('tr', {'id': f'detail{i + 2}'}):
                    break

        # 遍历每个 <tr> 标签，提取相关信息
        for product in product_more:
            # 提取所有 <td> 标签
            td_elements = product.find_all('td', class_='detail')

            # 如果该行数据少于 3 个 <td> 标签，则打印商品编号和商品名
            if len(td_elements) < 3:
                product_id = td_elements[0].get_text(strip=True) if len(td_elements) > 0 else "N/A"
                product_name = td_elements[1].get_text(strip=True) if len(td_elements) > 1 else "N/A"
                print(f"商品编号: {product_id}")
                print(f"商品名: {product_name}")
                continue  # 跳过后续的字段提取，进入下一行数据处理

            # 提取商品的其他信息
            price = td_elements[0].get_text(strip=True) if len(td_elements) > 0 else "N/A"
            standard_price = td_elements[1].get_text(strip=True) if len(td_elements) > 1 else "N/A"
            price_rate = td_elements[2].get_text(strip=True) if len(td_elements) > 2 else "N/A"
            sales_number = td_elements[3].get_text(strip=True) if len(td_elements) > 3 else "N/A"
            sales_ratio = td_elements[4].get_text(strip=True) if len(td_elements) > 4 else "N/A"
            avg_sales_per_day = td_elements[5].get_text(strip=True) if len(td_elements) > 5 else "N/A"
            upt = td_elements[6].get_text(strip=True) if len(td_elements) > 6 else "N/A"
            ustt = td_elements[7].get_text(strip=True) if len(td_elements) > 7 else "N/A"
            total_sales = td_elements[8].get_text(strip=True) if len(td_elements) > 8 else "N/A"
            sales_percentage = td_elements[9].get_text(strip=True) if len(td_elements) > 9 else "N/A"
            original_price = td_elements[10].get_text(strip=True) if len(td_elements) > 10 else "N/A"
            original_price_percentage = td_elements[11].get_text(strip=True) if len(td_elements) > 11 else "N/A"
            gross_profit = td_elements[12].get_text(strip=True) if len(td_elements) > 12 else "N/A"
            gross_profit_percentage = td_elements[13].get_text(strip=True) if len(td_elements) > 13 else "N/A"

            # 打印商品信息
            print(f"价格: {price}")
            #print(f"标准原价: {standard_price}")
            #print(f"原价率: {price_rate}")
            print(f"销售数: {sales_number}")
            #print(f"销售数构成比: {sales_ratio}")
            print(f"日平均销售数: {avg_sales_per_day}")
            #print(f"UPT: {upt}")
            #print(f"USTT: {ustt}")
            #print(f"总销售金额: {total_sales}")
            #print(f"销售金额构成比: {sales_percentage}")
            #print(f"标准成本: {original_price}")
            #print(f"成本构成比: {original_price_percentage}")
            #print(f"毛利额: {gross_profit}")
            #print(f"毛利额构成比: {gross_profit_percentage}")
            print("-" * 40)

        # 增加 i 进行下一次查找
        i += 1

if __name__ == '__main__':
    custom_start_date = "20251020"  # 自定义起始日期
    custom_end_date = "20251026"  # 自定义终止日期
    chooseData = "20251027"
    getProduct(custom_start_date=custom_start_date, custom_end_date=custom_end_date, seldate=0, chooseData=chooseData)
