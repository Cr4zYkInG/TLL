#!/usr/bin/env python3
"""
Generate QR code for App Store link
Uses qrcode library or online API
"""

import sys
import requests
from urllib.parse import quote

def generate_qr_online(text, filename="app-store-qr.svg", size=200):
    """Generate QR code using online API (free tier)"""
    api_url = f"https://api.qrserver.com/v1/create-qr-code/?size={size}x{size}&data={quote(text)}"
    
    try:
        response = requests.get(api_url)
        if response.status_code == 200:
            with open(filename, 'wb') as f:
                f.write(response.content)
            print(f"✅ QR code saved to {filename}")
            return True
        else:
            print(f"❌ API request failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error generating QR code: {e}")
        return False

def generate_qr_with_library(text, filename="app-store-qr.svg", size=200):
    """Generate QR code using qrcode library (if installed)"""
    try:
        import qrcode
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(text)
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        img.save(filename)
        print(f"✅ QR code saved to {filename}")
        return True
    except ImportError:
        print("❌ qrcode library not installed. Install with: pip install qrcode[pil]")
        return False

def main():
    # Replace with your actual App Store URL when available
    app_store_url = "https://apps.apple.com/app/thinklikelaw/idXXXXXXXXX"  # Replace with real App Store ID
    
    if len(sys.argv) > 1:
        app_store_url = sys.argv[1]
    
    print("🔍 Generating QR code for App Store...")
    print(f"📱 URL: {app_store_url}")
    
    # Try library first, then online API
    if not generate_qr_with_library(app_store_url):
        generate_qr_online(app_store_url)

if __name__ == "__main__":
    main()