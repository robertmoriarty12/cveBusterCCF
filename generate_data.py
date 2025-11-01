"""
cveBuster Data Generator
Generates 10 fresh vulnerability records with randomized data and current timestamps
Run this script whenever you need fresh data for the API to serve
"""

import json
import random
from datetime import datetime, timedelta

# Configuration: 20 unique VM names to choose from (randomly select 10 per run)
VM_NAMES = [
    "WebServer01", "WebServer02", "WebServer03", "WebServer04",
    "DBServer01", "DBServer02", "DBServer03",
    "AppServer01", "AppServer02", "AppServer03",
    "FileServer01", "FileServer02",
    "DCServer01", "DCServer02",
    "EicarVM", "TestVM01", "TestVM02",
    "ProdServer01", "ProdServer02", "DevServer01"
]

# IP ranges for random generation
IP_PREFIXES = ["10.0.0", "10.0.1", "10.0.2", "172.16.0", "192.168.1"]

# OS Families
OS_FAMILIES = [
    "Windows Server 2019",
    "Windows Server 2022",
    "Ubuntu 20.04",
    "Ubuntu 22.04",
    "Red Hat Enterprise Linux 8",
    "Red Hat Enterprise Linux 9",
    "CentOS 7",
    "Debian 11"
]

# Vulnerable Applications with their typical paths
APPLICATIONS = [
    {"name": "Apache", "path": "/usr/sbin/apache2"},
    {"name": "Nginx", "path": "/usr/sbin/nginx"},
    {"name": "Exim", "path": "/opt/exim/bin"},
    {"name": "Zoho ManageEngine", "path": "/opt/zoho_manageengine/bin"},
    {"name": "Microsoft Exchange", "path": "C:\\Program Files\\Microsoft\\Exchange Server"},
    {"name": "Apache Tomcat", "path": "/opt/tomcat/bin"},
    {"name": "Jenkins", "path": "/var/lib/jenkins"},
    {"name": "Docker", "path": "/usr/bin/docker"},
    {"name": "Kubernetes", "path": "/usr/local/bin/kubectl"},
    {"name": "Redis", "path": "/usr/bin/redis-server"},
    {"name": "PostgreSQL", "path": "/usr/lib/postgresql"},
    {"name": "MySQL", "path": "/usr/bin/mysql"},
    {"name": "Elasticsearch", "path": "/usr/share/elasticsearch"},
    {"name": "Apache Struts", "path": "/opt/struts/lib"},
    {"name": "Log4j", "path": "/opt/apps/lib/log4j"}
]

# CVE database (sample vulnerabilities)
VULNERABILITIES = [
    {"id": "CVE-2021-44228", "title": "Log4j Remote Code Execution", "cvss": 10.0},
    {"id": "CVE-2022-26134", "title": "Atlassian Confluence RCE", "cvss": 9.8},
    {"id": "CVE-2020-10189", "title": "Exim remote command execution", "cvss": 8.2},
    {"id": "CVE-2022-29144", "title": "ManageEngine RCE", "cvss": 8.5},
    {"id": "CVE-2023-23397", "title": "Microsoft Outlook Privilege Escalation", "cvss": 9.1},
    {"id": "CVE-2023-32315", "title": "Openfire Authentication Bypass", "cvss": 8.6},
    {"id": "CVE-2021-26855", "title": "Microsoft Exchange Server RCE", "cvss": 9.0},
    {"id": "CVE-2022-22965", "title": "Spring4Shell RCE", "cvss": 9.8},
    {"id": "CVE-2023-22515", "title": "Atlassian Confluence Privilege Escalation", "cvss": 8.8},
    {"id": "CVE-2022-41040", "title": "Microsoft Exchange ProxyNotShell", "cvss": 8.8},
    {"id": "CVE-2023-34362", "title": "MOVEit Transfer SQL Injection", "cvss": 9.8},
    {"id": "CVE-2022-30190", "title": "Microsoft Follina", "cvss": 7.8},
    {"id": "CVE-2023-0669", "title": "Fortra GoAnywhere MFT RCE", "cvss": 9.8},
    {"id": "CVE-2021-34527", "title": "PrintNightmare", "cvss": 8.8},
    {"id": "CVE-2023-38831", "title": "WinRAR Code Execution", "cvss": 7.8}
]

# Severity levels
SEVERITIES = ["Critical", "High", "Medium", "Low"]

# Asset Criticality
ASSET_CRITICALITY = ["Critical", "High", "Medium", "Low"]

# Business Owners
BUSINESS_OWNERS = ["SecEng", "IT-Ops", "DevOps", "Platform-Team", "Infrastructure"]


def generate_host_id():
    """Generate a random GUID-style host ID"""
    import uuid
    return str(uuid.uuid4())


def generate_ip_address():
    """Generate a random private IP address"""
    prefix = random.choice(IP_PREFIXES)
    last_octet = random.randint(2, 254)
    return f"{prefix}.{last_octet}"


def get_severity_from_cvss(cvss):
    """Determine severity based on CVSS score"""
    if cvss >= 9.0:
        return "Critical"
    elif cvss >= 7.0:
        return "High"
    elif cvss >= 4.0:
        return "Medium"
    else:
        return "Low"


def generate_random_datetime(days_ago_min=1, days_ago_max=60):
    """Generate a random datetime in the past"""
    now = datetime.utcnow()
    days_ago = random.randint(days_ago_min, days_ago_max)
    random_date = now - timedelta(days=days_ago)
    return random_date.strftime("%Y-%m-%dT%H:%M:%SZ")


def generate_record():
    """Generate a single vulnerability record"""
    vm_name = random.choice(VM_NAMES)
    host_id = generate_host_id()
    ip_address = generate_ip_address()
    os_family = random.choice(OS_FAMILIES)
    
    app = random.choice(APPLICATIONS)
    vuln = random.choice(VULNERABILITIES)
    
    cvss = vuln["cvss"]
    severity = get_severity_from_cvss(cvss)
    
    # Generate timestamps
    first_seen_days = random.randint(30, 90)
    last_seen_days = random.randint(1, 29)
    
    first_seen = generate_random_datetime(first_seen_days, first_seen_days + 10)
    last_seen = generate_random_datetime(last_seen_days, last_seen_days + 5)
    last_scan = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")  # Current time
    
    record = {
        "MachineName": vm_name,
        "HostId": host_id,
        "IPAddress": ip_address,
        "OSFamily": os_family,
        "Application": app["name"],
        "AppFilePath": app["path"],
        "VulnId": vuln["id"],
        "VulnTitle": vuln["title"],
        "Severity": severity,
        "CVSS": cvss,
        "ExploitAvailable": random.choice([True, False]),
        "ExploitedInWild": random.choice([True, False]),
        "PatchAvailable": random.choice([True, False]),
        "FirstSeen": first_seen,
        "LastSeen": last_seen,
        "LastScanTime": last_scan,
        "AssetCriticality": random.choice(ASSET_CRITICALITY),
        "BusinessOwner": random.choice(BUSINESS_OWNERS),
        "Source": "cveBuster:demo"
    }
    
    return record


def generate_data_file(num_records=10, output_file="cvebuster_data.json"):
    """Generate vulnerability data and save to JSON file"""
    
    print(f"🔄 Generating {num_records} fresh cveBuster vulnerability records...")
    
    # Select 10 unique VMs from the pool of 20
    selected_vms = random.sample(VM_NAMES, num_records)
    
    records = []
    for i in range(num_records):
        record = generate_record()
        # Override with selected VM to ensure uniqueness
        record["MachineName"] = selected_vms[i]
        records.append(record)
    
    # Write to JSON file
    with open(output_file, 'w') as f:
        json.dump(records, f, indent=2)
    
    print(f"✅ Successfully generated {num_records} records")
    print(f"📁 Saved to: {output_file}")
    print(f"⏰ Generation time: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC")
    print(f"\n📊 Sample record preview:")
    print(json.dumps(records[0], indent=2))


if __name__ == "__main__":
    generate_data_file(num_records=10, output_file="cvebuster_data.json")
