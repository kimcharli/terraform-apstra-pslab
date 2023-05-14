#!/usr/bin/env python3.11

from typing import List, Optional
from apstra_session import CkApstraSession
from apstra_blueprint import CkApstraBlueprint


class CkLinkSystem:
    def __init__(
        self,
        label: str,
        intf_name: str,
    ) -> None:
        self.label = label
        self.id = None
        self.intf_name = intf_name
        self.intf_id = None

class CkLink:
    def __init__(
        self,
        system1_label: str,
        system1_if_name: str,
        system2_label: str,
        system2_if_name: str,
        speed: str
        ) -> None:
        self.system1 = CkLinkSystem(system1_label, system1_if_name)
        self.system2 = CkLinkSystem(system2_label, system2_if_name)
        self.speed = speed
        self.id = None


class CkApstraGenericSystem:
    def __init__(
        self, 
        session: CkApstraSession, 
        blueprint: CkApstraBlueprint, 
        label: str, 
        hostname: str, 
        logical_device: str, 
        tags: List[str],
        intf_name1: str,
        system1_label: str, 
        system1_if_name: str,
        intf_name2: str,
        system2_label: str, 
        system2_if_name: str,
        speed: int
    ) -> None:
        self.session = session
        self.blueprint = blueprint
        self.label = label
        self.hostname = hostname
        self.logical_device = logical_device
        self.tags = tags
        self.intf_name1 = intf_name1
        self.system1_label = system1_label
        self.system1_if_name = system1_if_name
        self.intf_name2 = intf_name2
        self.system2_label = system2_label
        self.system2_if_name = system2_if_name
        self.speed = speed
        self.id = None
        self.interface_id = None  # TODO: multiple links
        self.get_gs_id()

    def get_gs_id(self) -> Optional[str]:
        '''Return the generic system id or None if not found'''
        system_label_query = f"node('system', label='{self.label}', name='system')"
        found_system = self.blueprint.query(system_label_query)
        # print(f"get_gs_id: {found_system=}")
        if len(found_system) > 0:
            self.id = found_system[0]['system']['id']
            self.print_id()
        return self.id

    def get_transformation_id(self, device_profile_id: str, intf_name: str, speed: int) -> Optional[str]:
        """
        Return transformation_id if the interface name and speed match.
        
        Args:
            device_profile_id (str): The device profile ID.
            intf_name (str): The interface name.
            speed (int): The speed value.

        Returns:
            str: The transformation ID, or None if not found.
        """
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

    def add_generic_system(self) -> None:
        '''Add a generic system to the blueprint if it does not exist'''
        if self.id is not None:
            print(f"add_generic_system: Generic system {self.label} already exists")
            return
        system1 = self.blueprint.get_system_with_im(self.system1_label)
        tfid1 = self.get_transformation_id(system1['im']['device_profile_id'], self.system1_if_name, self.speed)
        system2 = self.blueprint.get_system_with_im(self.system2_label)
        tfid2 = self.get_transformation_id(system2['im']['device_profile_id'], self.system1_if_name, self.speed)
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
        new_link_ids = self.blueprint.add_generic_system(self.gs_dict)
        if new_link_ids is None or len(new_link_ids) < 1:
            print(f"add_generic_system: Generic system {self.label} not created")
            return
        # new_links = new_generic_system.json()
        print(f"add_generic_system: {new_link_ids=}")
        # make lacp_active if system2_label is not None
        if self.system2_label is not None:
            update_dict = {
                "links": {
                    f"{new_link_ids[0]}": {
                        "group_label": "link1",
                        "lag_mode": "lacp_active"
                    },
                    f"{new_link_ids[1]}": {
                        "group_label": "link1",
                        "lag_mode": "lacp_active"
                    }
                }
            }
        link_updated = self.blueprint.patch_leaf_server_link(update_dict)

        # 
        # Request URL: https://10.85.192.50/api/blueprints/17b982a1-5023-48e2-88e5-5707e3e154b0/cabling-map?comment=cabling-map-update
        # Request Method: PATCH
        # Status Code: 204 NO CONTENT
        #
        # {"links":[
        #     {   "endpoints":[{"interface":{"id":"wN_ld_OxaQPkvyi2FXU"}},{"interface":{"if_name":"eth0","id":"6To186vmAGbnKU_j9dY"}}],
        #         "id":"pslab_server_001_leaf2<->gs-0004(link-000000002)[1]"
        #     },
        #     {   "endpoints":[{"interface":{"id":"XU3SOJN0iXlXBTW_LSM"}},{"interface":{"if_name":"eth1","id":"3wsDQy9hOK8jlucqgpY"}}],
        #         "id":"pslab_server_001_leaf1<->gs-0004(link-000000001)[1]"
        #     }
        # ]}

        self.get_gs_id()
        self.get_interface_id()
        print(f"add_generic_system: generic_system {self.label} created with {self.id=}, {self.interface_id=}")


    def delete_generic_system(self) -> None:
        '''Delete a generic system from the blueprint if it exists'''
        if self.id is None:
            print(f"delete_generic_system: Generic system {self.label} does not exist")
            return
        interface_query = f"node('system', label='{self.label}').out().node('interface', name='gs_intf').out().node('link', name='link').in_().node('interface', name='interface').where(lambda gs_intf, interface: gs_intf != interface)"
        found_interface = self.blueprint.query(interface_query)
        links = [link['link']['id'] for link in found_interface if link['interface']['if_type'] != "port_channel"]
        batch_spec = {
            "operations": [{
                "path":"/delete-switch-system-links","method":"POST",
                "payload": {
                    "link_ids": links
                    }
                }]
            }
        batch_response = self.blueprint.batch(batch_spec, params={"comment": "batch-api"})
        print(f"delete_generic_system: {batch_spec=} {batch_response=}")


    def get_interface_id(self) -> Optional[str]:
        '''Return the link id or None if not found
        TODO: use interface name for multiple link casses
        '''
        if self.interface_id is not None:
            return self.interface_id
        interface_query = f"node('system', label='{self.label}').out().node('interface', name='gs_intf').out().node('link').in_().node('interface', name='interface').where(lambda gs_intf, interface: gs_intf != interface)"
        found_interface = self.blueprint.query(interface_query)
        ae_interface_id = [link['interface']['id'] for link in found_interface if link['interface']['if_type'] == "port_channel"]
        print(f"get_interface_id: {ae_interface_id=}")
        if len(ae_interface_id) > 0:
            self.interface_id = ae_interface_id[0]
            return self.interface_id
        interface_id = [link['interface']['id'] for link in found_interface if link['interface']['if_type'] == "ethernet"]
        self.interface_id = interface_id[0]
        return self.interface_id


    def print_id(self) -> None:
        print(f"{self.id=}")


if __name__ == "__main__":
    apstra = CkApstraSession("10.85.192.50", 443, "admin", "zaq1@WSXcde3$RFV")
    bp = CkApstraBlueprint(apstra, "pslab")
    # gs = CkApstraGenericSystem(apstra, bp, "gs-0002", "host-0002", "AOS-2x10-1", ["server"], "pslab_server_001_leaf1", "xe-0/0/12", "pslab_server_001_leaf2", "xe-0/0/13", 10)
    # gs = CkApstraGenericSystem(apstra, bp, "gs-0003", "host-0003", "AOS-2x10-1", ["server"], "pslab_server_001_leaf1", "xe-0/0/14", "pslab_server_001_leaf2", "xe-0/0/14", 10)
    gs = CkApstraGenericSystem(apstra, bp, "gs-0004", "host-0004", "AOS-2x10-1", ["server"], "eth0", "pslab_server_001_leaf1", "xe-0/0/15", "eth1", "pslab_server_001_leaf2", "xe-0/0/15", 10)
    gs.add_generic_system()

