#!/usr/bin/env python

from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManage
from selenium.webdriver.chrome.options import Options

chromedriver_path = "/usr/local/bin/chromedriver"

options = Options()
options.add_argument("--window-size=1920x1080")
options.add_argument("--verbose")
# options.add_argument("--headless")

driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()))



driver = webdriver.Chrome(options=options, executable_path=chromedriver_path)
driver.get("https://www.example.com")

print(driver.find_element_by_css_selector('body').text)

# s = driver.get_window_size()
# #obtain browser height and width
# w = driver.execute_script('return document.body.parentNode.scrollWidth')
# h = driver.execute_script('return document.body.parentNode.scrollHeight')
# #set to new window size
# driver.set_window_size(w, h)
# #obtain screenshot of page within body tag
# driver.find_element_by_tag_name('body').screenshot("tutorialspoint.png")
# driver.set_window_size(s['width'], s['height'])
# driver.quit()
