#!/bin/python3
# lookup.py
# Unified structure for package manager operations
pkg_managers = {
    "debian": {
        "pm": "apt",
        "install": "install",
        "remove": "remove",
        "args": "-y"
    },
    "arch": {
        "pm": "pacman",
        "install": "-S",
        "remove": "-R",
        "args": "--noconfirm"
    },
    "alpine": {
        "pm": "apk",
        "install": "add",
        "remove": "del",
        "args": "--nocache"
    }
}

import subprocess
def is_installed(pkg, pm, dist_fam):
    if dist_fam == "debian":
        check_cmd = ["dpkg", "-l"]
    elif dist_fam == "arch":
        check_cmd = ["pacman", "-Qs", pkg]
    elif dist_fam == "alpine":
        check_cmd = ["apk", "list", "--installed"]
    else:
        return False
    
    try:
        result = subprocess.run(check_cmd, capture_output=True, text=True)
        return pkg in result.stdout
    except Exception as e:
        print(f"Check failed: {e}")
        return False

def get_os_fields(field: str) -> str:
    try:
        result = subprocess.run(
            ["grep", "-oP", fr'(?<=^{field}=)[^\n]*', "/etc/os-release"],
            capture_output=True, text=True, check=True
        )
        return rline(result.stdout)
    except subprocess.CalledProcessError:
        return ""

def rline(res):
    return res.strip()



