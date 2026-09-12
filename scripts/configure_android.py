"""Configure the generated Android target for Şifa's HTTPS API."""
from pathlib import Path
import xml.etree.ElementTree as ET

ANDROID = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID)
manifest = Path(__file__).resolve().parents[1] / "flutter_client/android/app/src/main/AndroidManifest.xml"
tree = ET.parse(manifest)
root = tree.getroot()
permission = f"{{{ANDROID}}}name"
if not any(p.get(permission) == "android.permission.INTERNET" for p in root.findall("uses-permission")):
    root.insert(0, ET.Element("uses-permission", {permission: "android.permission.INTERNET"}))
application = root.find("application")
if application is None:
    raise RuntimeError("Android application element is missing")
application.set(f"{{{ANDROID}}}label", "Şifa Kiralık Takip")
tree.write(manifest, encoding="utf-8", xml_declaration=True)
