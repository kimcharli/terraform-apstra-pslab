#!/usr/bin/env python3.11

from apstra_session import CkApstraSession

class CkApstraBlueprint:

    def __init__(self, session: CkApstraSession, label) -> None:
        self.session = session
        self.label = label
        self.id = None
        self.get_id()
        self.url_prefix = f"{self.session.url_prefix}/blueprints/{self.id}"

    def get_id(self):
        url = f"{self.session.url_prefix}/blueprints"
        blueprints = self.session.session.get(url).json()['items']
        for blueprint in blueprints:
            if blueprint['label'] == self.label:
                self.id = blueprint['id']
                break
        return self.id

    def print_id(self):
        print(f"{self.id=}")

    def query(self, query):
        url = f"{self.url_prefix}/qe"
        payload = {
            "query": query
        }
        response = self.session.session.post(url, json=payload)
        # print (f"{query=}, {response.json()=}")
        return response.json()['items']
    
    # return the first entry for the system
    def get_system_with_im(self, label):
        return self.query(f"node('system', label='{label}', name='system').out().node('interface_map', name='im')")[0]


    def add_generic_system(self, gs_spec):
        # Request URL: https://10.85.192.50/api/blueprints/17b982a1-5023-48e2-88e5-5707e3e154b0/switch-system-links
        return self.session.session.post(f"{self.url_prefix}/switch-system-links", json=gs_spec)

    def patch_leaf_server_link(self, link_spec):
        # Request URL: https://10.85.192.50/api/blueprints/17b982a1-5023-48e2-88e5-5707e3e154b0/leaf-server-link-labels
        return self.session.session.patch(f"{self.url_prefix}/leaf-server-link-labels", json=link_spec)

    def patch_obj_policy_batch_apply(self, policy_spec, params=None):
        '''
        Apply policies in a batch
        '''
        return self.session.session.patch(f"{self.url_prefix}/obj-policy-batch-apply", json=policy_spec, params=params)

    def batch(self, batch_spec, params=None):
        '''
        Run API commands in batch
        #         Request URL: https://10.85.192.50/api/blueprints/17b982a1-5023-48e2-88e5-5707e3e154b0/batch?comment=batch-api
        # Request Method: POST
        '''
        return self.session.session.post(f"{self.url_prefix}/batch", json=batch_spec, params=params)


if __name__ == "__main__":
    apstra = CkApstraSession("10.85.192.50", 443, "admin", "zaq1@WSXcde3$RFV")
    bp = CkApstraBlueprint(apstra, "pslab")
    bp.print_id()

