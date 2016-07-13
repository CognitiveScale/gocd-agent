#!/usr/bin/env python
from __future__ import print_function
import requests, re, sys, json, os, yaml, getopt
from requests.packages.urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

def load_compose(file):
    with open(file, 'r') as stream:
        return yaml.load(stream)

def eprint(str):
    print(str,file=sys.stderr)

def merge_dict(original, update):
    """
    Recursively update a dict.
    Subdict's won't be overwritten but also updated.
    """
    for key, value in original.iteritems():
        if key not in update:
            update[key] = value
        elif isinstance(value, dict):
            merge_dict(value, update[key])
    return update

def get_compose_services(compose):
    services = {}
    for key in compose:
        if not compose[key].has_key('image'): continue
        services[key] = get_image_parts(compose[key].get('image'))
    return services

def get_image_parts(image):
    image_parts = image.split(':')
    if len(image_parts) < 2: image_parts.append('latest')
    return {'image': image_parts[0], 'tag': image_parts[1]}

def get_version_env(services, images):
     return { service: { 'image': images[image] }  for image in images  for service in services
         if service.startswith(image) }

def print_report_entry(rpt):
    eprint ("Applying service: {} image: {} built_on: {}".format(rpt['name'],rpt['docker_tag'],rpt['timestamp']))

def get_pipeline_versions(url,artifact,username,password):
    r=requests.get("{}files/{}/Build/buildReport.json".format(url,artifact),auth=(username,password),verify=False)
# If the artifact isn't found in the new location try the old one ...
    if r.status_code == 404:
       r=requests.get("{}files/{}/Build/reports/buildReport.json".format(url,artifact),auth=(username,password),verify=False)
    r.raise_for_status()
    str = r.text
    try:
        rpt = json.loads(str)
        if isinstance(rpt,list):
            for d in rpt:
               print_report_entry(d)
            return { d['name']: { 'image': d['docker_tag']} for d in rpt }
        else:
            print_report_entry(rpt)
            return { rpt['name']: { 'image': rpt ['docker_tag'] }}
    except ValueError as exception:
# if the document is unparsable JSON try and grep the values out..
        name = re.search("\"name\":[ ]?\"(.*)\"",str).group(1)
        image = re.search("\"docker_tag\":[ ]?\"(.*)\"",str).group(1)
        timestamp = re.search("\"timestamp\":[ ]?\"(.*)\"",str).group(1)
        eprint ("Applying service: {} image: {} built_on: {}".format(name,image,timestamp))
        return {name: { 'image':image}}

def match_locators(locators, services):
    # match locators and services on image names
    matched_locators = {}
    for locator in locators:
        locator_image_fq = locators[locator].get('image')
        locator_image = get_image_parts(locator_image_fq).get('image')
        for service in services:
            service_image = services[service].get('image')
            if service_image and service_image == locator_image:
                matched_locators[service] = { 'image': locator_image_fq }
                break
    return matched_locators

def usage():
    eprint("Usage: -s|--source <source> -u|--user <username> -p|--password <password>")
def main(argv):
    url=os.environ["GO_SERVER_URL"]
    source_composefile='docker-compose.yml'
    cduser=os.environ.get('CD_USER')
    cdpass=os.environ.get('CD_PASS')

    try:
        opts, args = getopt.getopt(sys.argv[1:], "hs:vu:p:", ["help", "source=","username=","password="])
    except getopt.GetoptError as err:
        # print help information and exit:
        eprint(str(err))  # will print something like "option -a not recognized"
        usage()
        sys.exit(2)
    output = None
    verbose = False
    for o, a in opts:
        if o == "-v":
            verbose = True
        elif o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-s", "--source"):
            source_composefile = a
        elif o in ("-u", "--username"):
            cduser = a
        elif o in ("-p", "--password"):
            cdpass = a
        else:
            assert False, "unhandled option"
    # ...

    source=load_compose(source_composefile)
    images={ key.split('_')[1].lower(): os.environ[key] for key in os.environ.keys() if key.startswith("IMAGE_") }
    services = get_compose_services(source)
    eprint ("Found these services in the compose file")
    eprint (services)
    eprint ("Applying static images from env")
    static_versions = get_version_env(services,images)
    eprint (static_versions)
    withstaticversions=merge_dict(source,static_versions)
    eprint("Pulling versions from parent pipeline(s)")
    locators={ k: v for d in [ get_pipeline_versions(url,os.environ.get(key),cduser,cdpass)
            for key in os.environ.keys()
                if key.startswith("GO_DEPENDENCY_LOCATOR_")] for k, v in d.items() }
    matched_locators = match_locators(locators, services)
    withversions=merge_dict(withstaticversions, matched_locators)
    print(yaml.safe_dump(withversions,indent=2, default_flow_style=False))

if __name__ == "__main__":
    main(sys.argv[1:])
