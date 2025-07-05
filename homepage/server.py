#!/usr/bin/env python3
"""
SkyLab Homepage Server
A simple HTTP server to serve the SkyLab homelab dashboard
"""

import http.server
import socketserver
import os
import sys
from pathlib import Path

# Configuration
PORT = 8888
HOST = '0.0.0.0'  # Listen on all interfaces

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Custom handler to serve files with proper MIME types"""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(Path(__file__).parent), **kwargs)
    
    def end_headers(self):
        # Add security headers
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('X-Frame-Options', 'DENY')
        self.send_header('X-XSS-Protection', '1; mode=block')
        super().end_headers()
    
    def log_message(self, format, *args):
        """Custom log format with colors"""
        timestamp = self.log_date_time_string()
        client_ip = self.address_string()
        message = format % args
        
        # Color codes
        GREEN = '\033[92m'
        BLUE = '\033[94m'
        YELLOW = '\033[93m'
        RESET = '\033[0m'
        
        print(f"{GREEN}[{timestamp}]{RESET} {BLUE}{client_ip}{RESET} - {YELLOW}{message}{RESET}")

def main():
    """Start the SkyLab homepage server"""
    
    # Change to the script directory
    script_dir = Path(__file__).parent
    os.chdir(script_dir)
    
    # Check if index.html exists
    if not (script_dir / 'index.html').exists():
        print("❌ Error: index.html not found in the current directory")
        sys.exit(1)
    
    try:
        with socketserver.TCPServer((HOST, PORT), CustomHTTPRequestHandler) as httpd:
            print("\n" + "="*60)
            print("🚀 SkyLab Homepage Server Starting...")
            print("="*60)
            print(f"📡 Server Address: http://{HOST}:{PORT}")
            print(f"📁 Serving Directory: {script_dir}")
            print(f"🌐 Access URL: http://localhost:{PORT}")
            
            # Try to get the actual IP address
            import socket
            try:
                # Connect to a remote address to determine local IP
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.connect(("8.8.8.8", 80))
                local_ip = s.getsockname()[0]
                s.close()
                print(f"🔗 Network Access: http://{local_ip}:{PORT}")
            except:
                pass
            
            print("\n💡 Quick Access Commands:")
            print(f"   • Local:   http://localhost:{PORT}")
            print(f"   • Stop:    Ctrl+C")
            print("\n" + "="*60)
            print("📊 Server Logs:")
            print("="*60)
            
            httpd.serve_forever()
            
    except KeyboardInterrupt:
        print("\n\n🛑 Server stopped by user")
    except OSError as e:
        if e.errno == 98:  # Address already in use
            print(f"❌ Error: Port {PORT} is already in use")
            print("💡 Try using a different port or stop the existing service")
        else:
            print(f"❌ Error starting server: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()