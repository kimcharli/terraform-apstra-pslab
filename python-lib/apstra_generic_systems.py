#!/usr/bin/env python3.11

from apstra_session import CkApstraSession
from apstra_blueprint import CkApstraBlueprint

class CkApstraGenericSystem:

    def __init__(self, 
                 session: CkApstraSession, 
                 blueprint: CkApstraBlueprint, 
                 label, hostname, logical_device, tags,
                 system1_label, system1_if_name,
                 system2_label, system2_if_name,
                 speed) -> None:
        self.session = session
        self.blueprint = blueprint
        self.label = label
        self.hostname = hostname
        self.logical_device = logical_device
        self.tags = tags
        self.system1_label = system1_label
        self.system1_if_name = system1_if_name
        self.system2_label = system2_label
        self.system2_if_name = system2_if_name
        self.speed = speed
        self.id = None


    def get_transformaion_id(self, device_profile_id, intf_name, speed):
        '''Return transformation_id if the interface name and speed match'''
        device_profile_result = self.session.get_device_profile(device_profile_id)
        ports_list = device_profile_result['ports']

        # self.logger.info(f"{ports_list=} {intf_name=} {speed=}")  # port_list is too verbose
        for port in ports_list:
            for transformation in port['transformations']:
                # print(f"{transformation=}")
                for intf in transformation['interfaces']:
                    if intf['name'] == intf_name:
                        print(f"debug {intf=}")
                    if intf['name'] == intf_name and intf['speed']['unit'] == 'G' and intf['speed']['value'] == int(speed): 
                        # self.logger.warning(f"{intf_name=}, {intf=}")
                        return transformation['transformation_id']

    def build_gs_dict(self):
        system1 = self.blueprint.get_system_with_im(self.system1_label)
        tfid1 = self.get_transformaion_id(system1['im']['device_profile_id'], self.system1_if_name, self.speed)
        system2 = self.blueprint.get_system_with_im(self.system2_label)
        tfid2 = self.get_transformaion_id(system2['im']['device_profile_id'], self.system1_if_name, self.speed)
        logical_device = self.session.get_logical_device(self.logical_device)
        # print(f"{logical_device=} for {self.logical_device=}")
        del logical_device['created_at']
        del logical_device['last_modified_at']
        self.gs_dict = {
            "links": [
                {
                    "lag_mode": None,
                    "switch": {
                        "system_id": system1['system']['id'],
                        "transformation_id": tfid1,
                        "if_name": self.system1_if_name
                    },
                    "system": {
                        "system_id": None
                    }
                },
                {
                    "lag_mode": None,
                    "switch": {
                        "system_id": system2['system']['id'],
                        "transformation_id": tfid2,
                        "if_name": self.system2_if_name
                    },
                    "system": {
                        "system_id": None
                    }
                }
            ],
            "new_systems": [
                {
                    "system_type": "server",
                    "tags": self.tags,
                    "hostname": self.hostname,
                    "label": self.label,
                    "logical_device": logical_device
                }
            ]
        }
        # print(f"{self.gs_dict=}")
        new_links = self.blueprint.add_generic_system(self.gs_dict).json()
        # print(f"{new_links=}")
        # make lacp_active if system2_label is not None
        if self.system2_label is not None:
            update_dict = {
                "links": {
                    f"{new_links['ids'][0]}": {
                        "group_label": "link1",
                        "lag_mode": "lacp_active"
                    },
                    f"{new_links['ids'][1]}": {
                        "group_label": "link1",
                        "lag_mode": "lacp_active"
                    }
                }
            }
        link_updated = self.blueprint.patch_leaf_server_link(update_dict)
        print(f"{link_updated=}")


    def print_id(self):
        print(f"{self.id=}")


if __name__ == "__main__":
    apstra = CkApstraSession("10.85.192.50", 443, "admin", "zaq1@WSXcde3$RFV")
    bp = CkApstraBlueprint(apstra, "pslab")
    gs = CkApstraGenericSystem(apstra, bp, "gs-0002", "host-0002", "AOS-2x10-1", ["server"], "pslab_server_001_leaf1", "xe-0/0/12", "pslab_server_001_leaf2", "xe-0/0/13", 10)
    gs.build_gs_dict()
    gs.print_id()


