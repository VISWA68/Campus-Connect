import requests
import json

def add_new_user_and_get_recommendations(user_data):
    url = "http://localhost:5000/add_user"
    headers = {
        "Content-Type": "application/json"
    }
    
    try:
        print("\n=== Adding New User ===")
        print(f"Name: {user_data['name']}")
        print(f"Interests: {', '.join(user_data['interests'])}")
        print("\nFinding matching friends...")
        
        response = requests.post(url, headers=headers, json=user_data)
        
        if response.status_code == 200:
            result = response.json()
            print("\n=== Recommended Friends ===")
            for i, rec in enumerate(result['recommendations'], 1):
                print(f"\n{i}. {rec['name']} (ID: {rec['user_id']})")
                print(f"   Shared Interests: {', '.join(rec['interests'])}")
        else:
            print(f"Error: {response.status_code}")
            print(response.json())
            
    except Exception as e:
        print(f"Error making request: {e}")

def main():
    print("Welcome to Friend Matching System!")
    print("=================================")
    
    # Example of a new user
    new_user = {
        "user_id": 64,  # Next available ID
        "name": "vamsi",
        "interests": ["Rust","C++"]
    }
    
    # Add new user and get recommendations
    add_new_user_and_get_recommendations(new_user)

if __name__ == "__main__":
    # Make sure the Flask server is running before running this test
    print("Make sure the Flask server (matching.py) is running first!")
    input("Press Enter to start testing...")
    main()