from os import environ as env

from glanceclient import Client as glclient
import keystoneclient.v2_0.client as ksclient
import novaclient.v2.client as nvclient


client_args = {
        }

nova = nvclient.Client(auth_url=env['OS_AUTH_URL'],
        username=env['OS_USERNAME'],
        api_key=env['OS_PASSWORD'],
        project_id=env['OS_TENANT_NAME'])

keystone = ksclient.Client(auth_url=env['OS_AUTH_URL'],
        username=env['OS_USERNAME'],
        password=env['OS_PASSWORD'],
        tenant_name=env['OS_TENANT_NAME'],)

glance_endpoint = keystone.service_catalog.url_for(service_type='image')
glance = glclient(version=2, endpoint=glance_endpoint, token=keystone.auth_token)
