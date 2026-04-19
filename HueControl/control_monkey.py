#!/usr/bin/env python3
"""
Control the 'Monkey' office light via Tuya/Smart Life API.
"""
import urllib.request
import urllib.parse
import json
import sys
import os

# Device config
DEVICE_ID = "bf99f8444f9fa912130av1"
BASE_URL = "https://px1.tuyaeu.com/homeassistant/"

# Load creds from env (NEVER hardcode passwords in shared scripts)
USERNAME = os.environ.get("TUYA_USERNAME", "")
PASSWORD = os.environ.get("TUYA_PASSWORD", "")
COUNTRY_CODE = os.environ.get("TUYA_COUNTRY", "44") # 44 = EU
PLATFORM = os.environ.get("TUYA_PLATFORM", "smart_life")


def api_post(url, data, headers=None, is_json=True):
    if is_json:
        body = json.dumps(data).encode("utf-8")
        default_headers = {"Content-Type": "application/json"}
    else:
        body = urllib.parse.urlencode(data).encode("utf-8")
        default_headers = {"Content-Type": "application/x-www-form-urlencoded"}

    if headers:
        default_headers.update(headers)

    req = urllib.request.Request(url, data=body, headers=default_headers, method="POST")
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode("utf-8"))


def get_token():
    url = BASE_URL + "auth.do"
    data = {
        "userName": USERNAME,
        "password": PASSWORD,
        "countryCode": COUNTRY_CODE,
        "bizType": PLATFORM,
        "from": "tuya",
    }
    result = api_post(url, data, is_json=False)
    if "access_token" not in result:
        raise RuntimeError(f"Auth failed: {result}")
    return result["access_token"]


def get_device_state(token):
    url = BASE_URL + "skill"
    data = {
        "header": {"name": "Discovery", "namespace": "discovery", "payloadVersion": 1},
        "payload": {"accessToken": token},
    }
    result = api_post(url, data)
    for dev in result.get("payload", {}).get("devices", []):
        if dev.get("id") == DEVICE_ID:
            return dev.get("data", {})
    return None


def set_state(token, state):
    url = BASE_URL + "skill"
    data = {
        "header": {"name": "turnOnOff", "namespace": "control", "payloadVersion": 1},
        "payload": {
            "accessToken": token,
            "devId": DEVICE_ID,
            "value": 1 if state else 0,
        },
    }
    result = api_post(url, data)
    code = result.get("header", {}).get("code")
    return code == "SUCCESS"


def main():
    if not USERNAME or not PASSWORD:
        print("Error: Set TUYA_USERNAME and TUYA_PASSWORD environment variables.")
        sys.exit(1)

    if len(sys.argv) < 2:
        print("Usage: python3 control_monkey.py --on | --off | --status")
        sys.exit(1)

    cmd = sys.argv[1].lower()
    token = get_token()

    if cmd == "--on":
        ok = set_state(token, True)
        print("Monkey ON" if ok else "Failed to turn on")
    elif cmd == "--off":
        ok = set_state(token, False)
        print("Monkey OFF" if ok else "Failed to turn off")
    elif cmd == "--status":
        data = get_device_state(token)
        if data:
            print(f"State: {'ON' if data.get('state') else 'OFF'}")
            print(f"Online: {data.get('online', False)}")
        else:
            print("Device not found in discovery response")
    else:
        print("Unknown command. Use: --on | --off | --status")
        sys.exit(1)


if __name__ == "__main__":
    main()
