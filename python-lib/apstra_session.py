#!/usr/bin/env python3.11
import requests
import urllib3

# https client session to Apstra Controller
class CkApstraSession:

    def __init__(self, host, port, username, password) -> None:
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.token = None
        self.ssl_verify = False

        self.session = requests.Session()
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        self.session.verify = False
        self.session.headers.update({'Content-Type': "applycation/json"})
        self.url_prefix = f"https://{self.host}:{self.port}/api"

        self.login()


    def login(self):
        url = f"{self.url_prefix}/user/login"
        payload = {
            "username": self.username,
            "password": self.password
        }
        response = self.session.post(url, json=payload)
        # print(f"{response.raw=}")
        self.token = response.json()["token"]
        self.session.headers.update({'AuthToken': self.token})

    def get_device_profile(self, name = None):
        if name is None:
            print("get_device_profile: name is None")
            return None
            url = f"{self.url_prefix}/device-profiles"
            device_profiles = self.session.get(url).json()['items']
            for device_profile in device_profiles:
                if device_profile['name'] == name:
                    return device_profile
        url = f"{self.url_prefix}/device-profiles/{name}"
        return self.session.get(url).json()
    
    def get_logical_device(self, id = None):
        if id is None:
            print("get_logical_device: id is None")
            return None
        url = f"{self.url_prefix}/design/logical-devices/{id}"
        return self.session.get(url).json()

    def print_token(self):
        print(f"{self.token=}")


if __name__ == "__main__":
    apstra = CkApstraSession("10.85.192.50", 443, "admin", "zaq1@WSXcde3$RFV")
    apstra.print_token()

