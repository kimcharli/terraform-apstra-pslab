#!/usr/bin/env python3.11

import time


from apstra_generic_system import CkApstraGenericSystem
from apstra_session import CkApstraSession
from apstra_blueprint import CkApstraBlueprint

class CkApstraConnectivityTemplateInput:
    '''
    Input parameters for CkApstraConnectivityTemplate
    '''
    
    def __init__(self, 
                 label: str) -> None:
        self.label = label

class CkApstraConnectivityTemplate:

    def __init__(self, 
                 session: CkApstraSession, 
                 blueprint: CkApstraBlueprint, 
                 input: CkApstraConnectivityTemplateInput) -> None:
        self.session = session
        self.blueprint = blueprint
        self.input = input
        self.id = None

        policy_query = f"node('ep_endpoint_policy', label='{self.input.label}', ploicy_type_name='batch', name='connectivity_template')"
        found_policy = self.blueprint.query(f"node('ep_endpoint_policy', label='{self.input.label}', policy_type_name='batch', name='connectivity_template')")
        print(f"{policy_query=} {found_policy=}")
        if len(found_policy) > 0:
            self.id = found_policy[0]['connectivity_template']['id']
        print(f"id of {self.input.label}: {self.id}")


    def attach(self, application_point_id: str):
        '''
        Attach policy to the interfaces
        '''
        if self.id is None:
            print(f"ERROR: {self.id=}")
            return
        policy_spec = {
            "application_points": [
                {
                    "id": application_point_id,
                    "policies": [
                        {
                            "policy": self.id,
                            "used": True
                        }
                    ]
                }
            ]
        }
        print(f"{policy_spec=}")
        attached_policy = self.blueprint.patch_obj_policy_batch_apply(policy_spec, params={"async": "full"})        
        print(f"{attached_policy=}, {policy_spec=}")
        if attached_policy.status_code != 202:
                print(f"attach: ERROR: {attached_policy.status_code=}")


def delete_gs(gs):
    print("#### sleeping 5 seconds")
    time.sleep(5)
    print("#### deleting")
    gs.delete_generic_system()

def main():
    apstra = CkApstraSession("10.85.192.50", 443, "admin", "zaq1@WSXcde3$RFV")
    bp = CkApstraBlueprint(apstra, "pslab")
    gs = CkApstraGenericSystem(apstra, bp, "gs-0002", "host-0002", "AOS-2x10-1", ["server"], "pslab_server_001_leaf1", "xe-0/0/12", "pslab_server_001_leaf2", "xe-0/0/13", 10)
    gs.add_generic_system()
    ct_input = CkApstraConnectivityTemplateInput("vn100")
    ct = CkApstraConnectivityTemplate(apstra, bp, ct_input)
    ct.attach(gs.get_interface_id())

    delete_gs(gs)

if __name__ == '__main__':
    main()
