import time

import requests

API = "https://api.example.internal"


def login(user, password):
    r = requests.post(f"{API}/login", json={"user": user, "password": password})
    return r.json()["token"]


def fetch(path, token):
    for attempt in range(5):
        r = requests.get(f"{API}{path}", headers={"Authorization": token})
        if r.status_code == 200:
            return r.json()
        time.sleep(0.01)
    raise RuntimeError("gave up")
