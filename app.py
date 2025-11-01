"""
cveBuster Flask API Server
Simple REST API that serves vulnerability data from cvebuster_data.json
Designed for testing CCF polling connectors
"""

from flask import Flask, jsonify, request
import json
import os
from datetime import datetime

app = Flask(__name__)

# Configuration
DATA_FILE = "cvebuster_data.json"
API_KEY = "cvebuster-demo-key-12345"  # Simple API key for testing


def load_vulnerability_data():
    """Load vulnerability data from JSON file"""
    try:
        # Support both relative path and Desktop path for Ubuntu VM
        possible_paths = [
            DATA_FILE,
            os.path.join(os.path.expanduser("~"), "Desktop", DATA_FILE),
            os.path.join(os.path.dirname(__file__), DATA_FILE)
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                with open(path, 'r') as f:
                    return json.load(f)
        
        return {"error": f"Data file '{DATA_FILE}' not found in any expected location"}
    
    except Exception as e:
        return {"error": f"Failed to load data: {str(e)}"}


def verify_api_key():
    """Simple API key verification"""
    # Check for API key in Authorization header
    auth_header = request.headers.get('Authorization')
    
    if not auth_header:
        return False
    
    # Support both "Bearer <key>" and just "<key>"
    if auth_header.startswith('Bearer '):
        provided_key = auth_header.replace('Bearer ', '')
    else:
        provided_key = auth_header
    
    return provided_key == API_KEY


@app.route('/')
def home():
    """API information endpoint"""
    return jsonify({
        "service": "cveBuster API",
        "version": "1.0.0",
        "description": "Vulnerability data API for Microsoft Sentinel CCF testing",
        "endpoints": {
            "/api/vulnerabilities": "GET - Fetch all vulnerability records (requires API key)",
            "/health": "GET - Health check endpoint"
        },
        "authentication": "API Key required in Authorization header",
        "example": "curl -H 'Authorization: cvebuster-demo-key-12345' http://20.84.144.179:5000/api/vulnerabilities"
    })


@app.route('/health')
def health():
    """Health check endpoint"""
    data_exists = False
    possible_paths = [
        DATA_FILE,
        os.path.join(os.path.expanduser("~"), "Desktop", DATA_FILE),
        os.path.join(os.path.dirname(__file__), DATA_FILE)
    ]
    
    for path in possible_paths:
        if os.path.exists(path):
            data_exists = True
            break
    
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "data_file_loaded": data_exists
    })


@app.route('/api/vulnerabilities', methods=['GET'])
def get_vulnerabilities():
    """
    GET endpoint to retrieve all vulnerability records
    Requires API key authentication
    """
    
    # Verify API key
    if not verify_api_key():
        return jsonify({
            "error": "Unauthorized",
            "message": "Valid API key required in Authorization header"
        }), 401
    
    # Load and return vulnerability data
    data = load_vulnerability_data()
    
    if isinstance(data, dict) and "error" in data:
        return jsonify(data), 500
    
    # Return data with metadata
    response = {
        "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "count": len(data),
        "data": data
    }
    
    return jsonify(response), 200


@app.route('/api/vulnerabilities/count', methods=['GET'])
def get_vulnerability_count():
    """
    GET endpoint to retrieve count of vulnerability records
    Does not require authentication (useful for monitoring)
    """
    data = load_vulnerability_data()
    
    if isinstance(data, dict) and "error" in data:
        return jsonify({"count": 0, "error": data["error"]}), 500
    
    return jsonify({
        "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "count": len(data)
    })


if __name__ == '__main__':
    print("=" * 60)
    print("🚀 cveBuster API Server Starting...")
    print("=" * 60)
    print(f"📁 Looking for data file: {DATA_FILE}")
    print(f"🔑 API Key: {API_KEY}")
    print(f"🌐 Server will listen on: 0.0.0.0:5000")
    print(f"🔗 Access from: http://20.84.144.179:5000")
    print("=" * 60)
    print("\n📋 Test Commands:")
    print(f"\n  Health Check (no auth):")
    print(f"  curl http://20.84.144.179:5000/health")
    print(f"\n  Get Vulnerabilities (with auth):")
    print(f"  curl -H 'Authorization: {API_KEY}' http://20.84.144.179:5000/api/vulnerabilities")
    print(f"\n  Get Count (no auth):")
    print(f"  curl http://20.84.144.179:5000/api/vulnerabilities/count")
    print("\n" + "=" * 60 + "\n")
    
    # Run Flask app - accessible from external IPs
    app.run(host='0.0.0.0', port=5000, debug=True)
