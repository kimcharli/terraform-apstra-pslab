#!/usr/bin/env python3.11

import sys

from apstra_session import CkApstraSession
from apstra_blueprint import CkApstraBlueprint


# Prerequisite: apstra-cli
#
# 1. download the image apstracli-release_4.1.2.5.tar.gz from download page on a node (apstra controller, worker, or ztp server)
#
# admin@apstra-50-412:~$ curl "https://cdn.juniper.net/software/jafc/4.1.2/apstracli-release_4.1.2.5.tar.gz?SM_USER=ckim&__gda__=1686172507_db52fc783c866980f640332718b8f453" -o apstracli-release_4.1.2.5.tar.gz
# admin@apstra-50-412:~$ ll apstracli-release_4.1.2.5.tar.gz 
# -rw------- 1 admin admin 148907081 Jun  7 21:26 apstracli-release_4.1.2.5.tar.gz
# admin@apstra-50-412:~$
#
# 2. load the image on the server
#
# admin@apstra-50-412:~$ docker load -i apstracli-release_4.1.2.5.tar.gz 
# Loaded image: apstracli:release_4.1.2.5
# admin@apstra-50-412:~$
#
# 3. run the cli on the server
#
# admin@apstra-50-412:~$ docker run -it --rm apstracli:release_4.1.2.5 -s 10.85.192.50 
# Password [admin]: 
# ----------------------------------------------------------------------------------------------------
# ****************************************************************************************************
#                              NOTE: This is a Limited Availability tool
#                 Use it ONLY under the strict supervision of Juniper Apstra personnel
# ****************************************************************************************************
# ----------------------------------------------------------------------------------------------------
# Welcome to Juniper Apstra CLI! Press TAB for suggestions
# Juniper Apstra CLI version: release-4.1.2.5
# Juniper Apstra Server URL: https://10.85.192.50:443, Version: 4.1.2-269
# apstra-cli> scenario change-device-password --blueprint 6227b878-bd67-4fc8-9ab2-e4fa654eab48 --old-password aosadmin123 --new-password 'zaq1@WSXcde3$RFV' --system mQkXXBDuFHEFxe7LH9I
# Change password for root user is not supported.
# Aborted.
# apstra-cli> 
#
#
# 4. run the script to update the agent profile of the devices and produce the string from a linux station
#
#
# 5. put the string to update password of the user aosadmin on the server
#
# apstra-cli> scenario change-device-password --blueprint 6227b878-bd67-4fc8-9ab2-e4fa654eab48 --old-password aosadmin123 --new-password 'zaq1@WSXcde3$RFV' --system 62UzbPq8MBr6CH769AA
# ================== START ========================
# 1/11)   Task:   Check old password by ssh connection
#                 Status: Check OK
# ================================================== 
# 2/11)   Task:   Stage creation of Configlet for password change
#                 Status: Staging OK (Configlet created)
# ================================================== 
# 3/11)   Task:   Commit Blueprint
#                 Status: Commit OK (Blueprint deployed with version 79)
# ================================================== 
# 4/11)   Task:   Check new password by ssh connection
#                 Status: Check OK
# ================================================== 
# 5/11)   Task:   Change System agent password
#                 Status: Change done
# ================================================== 
# 6/11)   Task:   Check System agent status
#                 Status: Check OK
# ================================================== 
# 7/11)   Task:   Update device pristine config
#                 Status: Update done
# ================================================== 
# 8/11)   Task:   Stage deletion of Configlet used for password change
#                 Status: Staging OK (Configlet deleted)
# ================================================== 
# 9/11)   Task:   Commit Blueprint
#                 Status: Commit OK (Blueprint deployed with version 80)
# ================================================== 
# 10/11)  Task:   Check new password by ssh connection
#                 Status: Check OK
# ================================================== 
# 11/11)  Task:   Check System agent status
#                 Status: Check OK
# ================== END ===========================
# apstra-cli> 
#



# usage: $0 <blueprint> <agent-profile> <device>
#    python apstra_change_device_password_string.py terra junos-aosadmin-default terra_server_001_leaf1
def main():
    bp_label = sys.argv[1]
    agent_profile = sys.argv[2]
    device_label = sys.argv[3]

    apstra = CkApstraSession("10.85.192.50", 443, "admin", "zaq1@WSXcde3$RFV")
    bp = CkApstraBlueprint(apstra, bp_label)
    if bp.id is None:
        return
    
    systems = { x['status']['system_id']: { 'id': x['id'] } for x in apstra.get_items('system-agents')['items'] }
    # print(f"{systems=}")

    agent_profile_ids = [ x['id'] for x in apstra.get_items('system-agent-profiles')['items'] if x['label'] == agent_profile ]
    # print(f"{agent_profile_ids}")


    system_nodes = { system['system']['label']: { 'id': system['system']['id'], 'sn': system['system']['system_id'] } for system in bp.query(f"node('system', name='system', system_type='switch')") }
    # iterate dictionary system_nodes and print the label and id
    for system in dict(sorted(system_nodes.items())):
        id = system_nodes[system]['id']
        sn = system_nodes[system]['sn']
        print(f"{system}: {id=}, {sn=}")
        if system == device_label:            
            patch_spec = {
                'username': 'aosadmin',
                # 'password': 'aosadmin123',
                'platform': 'junos',
                'profile': agent_profile_ids[0]
            }
            patched = apstra.patch_item( f"system-agents/{systems[sn]['id']}", patch_spec)
            print(f"{patched=}")
            print(f"\t scenario change-device-password --blueprint {bp.id} --old-password aosadmin123 --new-password 'zaq1@WSXcde3$RFV' --system {id}")
        else:
            continue


if __name__ == '__main__':
    main()

