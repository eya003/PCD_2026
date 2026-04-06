import requests
import json
import sys

base_url = "http://localhost:8000"

# Register a mock doctor or login
login_data = {
    "username": "12345678", # assuming cin is the username for OAuth2PasswordRequestForm
    "password": "password123"
}
# wait, auth endpoint uses Form data. Let's just create a user directly if needed.
# Let's try to just hit the endpoint, maybe see if there is a 500 error in the backend console?
