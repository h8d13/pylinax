import subprocess
from pack.env import is_user

def say_hello():
    subprocess.run(["echo", "Hello", is_user])
