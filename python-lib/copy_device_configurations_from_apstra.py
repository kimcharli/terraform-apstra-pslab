#!/usr/bin/env python3

import argparse
import getpass
import sys
import os
import json
import urllib3

# python3 $0 -s <apstra-IP> -b <blueprint-label> [-u <user-name>] [-p <password>] -o <output-dir> 
# python3 src/ps_apstra_python/copy_device_configurations_from_apstra.py -s 10.85.192.61 -b pslab -o ~/Downloads/test2_dir 
# python3 src/ps_apstra_python/copy_device_configurations_from_apstra.py -s 10.85.192.61 -b pslab  -o ~/Downloads/test2_dir -u admin -p admin
PROGNAME = 'get-device-configuration'



class CkAosServer:
    # http
    # json_header
    # json_token_header
    # token

    def __init__(self, server, port, user, password ) -> None:
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        self.http = urllib3.HTTPSConnectionPool(server, port=port, cert_reqs='CERT_NONE', assert_hostname=False)

        self.json_header = urllib3.response.HTTPHeaderDict({"Content-Type": "application/json"})
        self._auth(user, password)
        self.json_token_header = urllib3.response.HTTPHeaderDict({"Content-Type": "application/json", "AuthToken": self.token})

    def _auth(self, user, password) -> None:
        auth_url = "/api/aaa/login"
        auth_spec = {
            "username": user,
            "password": password
        }
        resp = self.http_post( auth_url, auth_spec, headers=self.json_header, expected=201)
        # print(f"{resp=}, {resp.status=}, {resp.data=}")
        self.token = json.loads(resp.data)["token"]

    def http_post(self, path, data, headers=None, expected=None) -> urllib3.response.HTTPResponse:
        print_prefix = "==== AosServer.http_post()"
        if not headers:
            headers = self.json_token_header
        # print(f"{print_prefix} {path}\n{data}")
        resp = self.http.request('POST', path, body=json.dumps(data), headers=headers)
        if expected:
            # print(f"{print_prefix} status (expect {expected}): {resp.status}")
            if resp.status != expected:
                print(f"{print_prefix} body: {resp.data}")
        else:
            print(f"{print_prefix} status: {resp.status}")
        return resp

    def http_get(self, path) -> urllib3.response.HTTPResponse:
        return self.http.request('GET', path, headers=self.json_token_header)
    
    def http_get_json(self, path):
        resp = self.http_get(path)
        return json.loads(resp.data)


class CkAosBlueprint:
    # server
    # label
    # id
    # systems = {node_id: [hostname, system_id], ... }
    def __init__(self, aos_server, bp_label: str, ) -> None:
        # print_prefix = "==== AosBp.__init():"
        self.server = aos_server
        self.label = bp_label

        resp = self.server.http_get_json("/api/blueprints")
        for i in resp["items"]:
            if i["label"] == self.label:
                self.id = i["id"]

    def get_systems(self):
        data = {
            'query': "node('system', name='system', role=is_in(['spine', 'leaf']))"
        }
        resp = self.server.http_post(f"/api/blueprints/{self.id}/qe", data)
        self.systems = { x['system']['id']: [x['system']['hostname'], x['system']['system_id']] for x in resp.json()['items'] }
    
    def get_rendering(self, node_id):
        # resp = self.server.http_get_json(f"/api/blueprints/{self.id}/systems/{system}/config-rendering")
        resp = self.server.http_get_json(f"/api/blueprints/{self.id}/nodes/{node_id}/config-rendering")
        if 'config' in resp:
            return resp['config']
        else:
            print(f"****** No config for {node_id}")
            return None

    def get_pristine(self, system):
        resp = self.server.http_get_json(f"/api/systems/{system}/pristine-config")
        return resp['pristine_data']

# ./copy_device_configurations_from_apstra.py -s 10.85.192.61 -u admin -p 'zaq1@WSXcde3$RFV' -b ATLANTA-Master -o /Users/ckim/Downloads/nf-mater
def main(args_test: list = None):
    parser = argparse.ArgumentParser(prog=PROGNAME)
    parser.add_argument(
        "-s", "--server", help="Provide the hostname of the Apstra Controller"
    )
    parser.add_argument(
        "-b", "--blueprint", help="Provide the blueprint label"
    )
    parser.add_argument(
        "-u", "--username", help="Provide the username of the Apstra Controller"
    )
    parser.add_argument(
        "-p", "--password", help="Provide the password"
    )
    parser.add_argument(
        "-o", "--output-dir", default=".", help="Provide the output dir to save configurations"
    )
    options = parser.parse_args(args_test) if args_test else parser.parse_args()

    output_folder_name = options.output_dir
    if not os.path.isdir(output_folder_name):
        os.mkdir(output_folder_name)

    begin_configlet = '------BEGIN SECTION CONFIGLETS------'
    begin_set = '------BEGIN SECTION SET AND DELETE BASED CONFIGLETS------'
    show_tech_config_path = 'main_sysdb_dump/device/deployment/config'
    show_tech_pristine_path = 'main_sysdb_dump/device/deployment/pristine'
    pristine_begin_mark = '<PRISTINE CONFIG BEGIN>'


    server = options.server
    username = options.username or input('Username: ')
    password = options.password or getpass.getpass(prompt='Password: ')

    # print(f"{options=}")
    server = CkAosServer(server, 443, username, password)
    bp = CkAosBlueprint(server, options.blueprint)
    bp.get_systems()
    for node_id, hostname_and_system_id in bp.systems.items():
        hostname, system_id = hostname_and_system_id
        print(f"==== {node_id=}, {hostname=}, {system_id=}")
        rendered_config = bp.get_rendering(node_id)
        print(f"-- Reading rendered configuration")
        config_string = rendered_config.split(begin_configlet)
        print(f"-- parsed config_string configuration, {len(config_string)=}")
        # see if configlet was applied
        if len(config_string) > 1:
            print(f"-- parsed configet configuration")
            configlet_string = config_string[1].split(begin_set)
            with open(f"{output_folder_name}/{hostname}-configlet.txt", 'w') as f:
                f.write(configlet_string[0])
            with open(f"{output_folder_name}/{hostname}-configlet-set.txt", 'w') as f:
                f.write(configlet_string[1])
        with open(f"{output_folder_name}/{hostname}.txt", 'w') as f:
            f.write(config_string[0])

        if system_id:
            print("-- Reading pristine configuration")
            pristine_config = bp.get_pristine(system_id)[0]['content']
            # print(f"{pristine_config=}")
            with open(f"{output_folder_name}/{hostname}-pristine.txt", 'w') as f:
                f.write(pristine_config)

        # sys.exit()

if __name__ == '__main__':
    main()
    

