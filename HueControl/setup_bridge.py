#!/usr/bin/env python3
"""
Hue Bridge Setup Script
Discovers your Hue Bridge and generates an API key.
"""

import json
import time
import urllib.request
import urllib.error


def discover_bridge():
    """Discover Hue Bridge using Philips discovery service."""
    print("🔍 Discovering Hue Bridge...")
    
    try:
        req = urllib.request.Request(
            "https://discovery.meethue.com/",
            headers={"Accept": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            bridges = json.loads(response.read())
            
        if not bridges:
            print("❌ No bridges found on network")
            return None
            
        print(f"✅ Found {len(bridges)} bridge(s):")
        for i, bridge in enumerate(bridges, 1):
            print(f"   {i}. {bridge['internalipaddress']} (ID: {bridge.get('id', 'unknown')})")
        
        return bridges[0]['internalipaddress']
        
    except Exception as e:
        print(f"❌ Discovery failed: {e}")
        return None


def create_api_key(bridge_ip):
    """Create new API key by pressing the bridge button."""
    print(f"\n🌉 Bridge found at: {bridge_ip}")
    print("\n⚠️  IMPORTANT: Press the PHYSICAL button on your Hue Bridge")
    print("    Then press ENTER within 30 seconds...")
    input()
    
    url = f"http://{bridge_ip}/api"
    data = json.dumps({"devicetype": "hue_control_mac#simon"}).encode()
    
    try:
        req = urllib.request.Request(url, data=data, headers={
            "Content-Type": "application/json"
        })
        
        with urllib.request.urlopen(req, timeout=10) as response:
            result = json.loads(response.read())
        
        if 'error' in result[0]:
            error = result[0]['error']
            if error['type'] == 101:
                print("❌ Button not pressed in time!")
                print("   Press the button and try again.")
            else:
                print(f"❌ Error: {error['description']}")
            return None
        
        if 'success' in result[0]:
            username = result[0]['success']['username']
            print(f"\n✅ SUCCESS!")
            print(f"\n📝 Your API Key: {username}")
            print(f"\n📝 Your Bridge IP: {bridge_ip}")
            print("\n👉 Update these in HueControl/HueControlApp.swift:")
            print(f"""
    struct HueConfig {{
        static let bridgeIP = "{bridge_ip}"
        static let apiKey = "{username}"
    }}
""")
            return username
            
    except urllib.error.URLError as e:
        print(f"❌ Connection failed: {e}")
        return None


def test_connection(bridge_ip, api_key):
    """Test the API key by fetching lights."""
    print("\n🧪 Testing connection...")
    
    url = f"http://{bridge_ip}/api/{api_key}/lights"
    
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            lights = json.loads(response.read())
        
        if 'error' in lights:
            print(f"❌ API Error: {lights['error']['description']}")
            return False
        
        print(f"✅ Connected! Found {len(lights)} light(s)")
        for light_id, light_data in lights.items():
            state = "🟡 ON" if light_data['state']['on'] else "⚫ OFF"
            print(f"   • {light_data['name']} {state}")
        
        return True
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False


def main():
    print("=" * 50)
    print("🎨 Hue Control - Bridge Setup")
    print("=" * 50)
    
    # Try discovery first
    bridge_ip = discover_bridge()
    
    # Fallback to manual entry
    if not bridge_ip:
        print("\n📝 Manual entry:")
        bridge_ip = input("Enter your Bridge IP (e.g., 192.168.50.228): ").strip()
    
    if not bridge_ip:
        print("❌ No bridge IP provided")
        return
    
    # Create API key
    api_key = create_api_key(bridge_ip)
    
    if api_key:
        # Test it
        test_connection(bridge_ip, api_key)
        
        print("\n" + "=" * 50)
        print("🎉 Setup complete! You're ready to build the app.")
        print("=" * 50)
    else:
        print("\n❌ Setup failed. Try again!")


if __name__ == "__main__":
    main()
