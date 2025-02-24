from flask import Flask, request, jodelsonify
from flask_cors import CORS
import faiss
import numpy as np
from pymongo import MongoClient

app = Flask(__name__)
CORS(app)

# MongoDB connection
client = MongoClient("mongodb+srv://v:viswa123@cluster0.dhc4mq5.mongodb.net/CampusConnect?retryWrites=true&w=majority")
db = client["Dummy"]
collection = db["users_with_interests"]

def get_all_users():
    return list(collection.find())

def initialize_faiss():
    global all_interests, interest_to_index, user_ids, user_vectors, index, dimension, id_map
    
    # Get all users from MongoDB
    users = get_all_users()
    
    # Unique interests
    all_interests = sorted({interest for user in users for interest in user["interests"]})
    interest_to_index = {interest: i for i, interest in enumerate(all_interests)}
    
    # Convert users to FAISS-compatible vectors
    user_ids = []
    user_vectors = []
    for user in users:
        user_ids.append(user["user_id"])
        user_vectors.append(encode_interests(user["interests"]))

    user_vectors = np.array(user_vectors, dtype=np.float32)
    
    # Create FAISS index
    dimension = len(all_interests)
    index = faiss.IndexFlatL2(dimension)
    if len(user_vectors) > 0:
        index.add(user_vectors)
    
    # Store user IDs
    id_map = {i: user["user_id"] for i, user in enumerate(users)}

# Encode interests as vectors
def encode_interests(user_interests):
    vector = np.zeros(len(all_interests), dtype=np.float32)
    for interest in user_interests:
        if interest in interest_to_index:
            vector[interest_to_index[interest]] = 1
    return vector

# Initialize FAISS
initialize_faiss()

# Function to recommend users
def recommend_users(target_user_id, top_n=3):
    if target_user_id not in user_ids:
        return []

    # Find target user's index
    target_index = user_ids.index(target_user_id)
    target_vector = user_vectors[target_index].reshape(1, -1)

    # Search for nearest neighbors
    distances, indices = index.search(target_vector, top_n + 1)
    
    recommended_users = []
    for i in indices[0][1:]:  # Skip first result (self)
        user_id = id_map.get(i)
        if user_id:
            user = collection.find_one({"user_id": user_id})
            if user:
                recommended_users.append({
                    "user_id": user_id,
                    "name": user["name"],
                    "interests": user["interests"]
                })

    return recommended_users

@app.route("/add_user", methods=["POST"])
def add_user():
    try:
        data = request.json
        new_user_id = data.get("user_id")
        new_user_name = data.get("name")
        new_interests = data.get("interests", [])

        # Validate input
        if not all([new_user_id, new_user_name, new_interests]):
            return jsonify({"error": "Missing required fields"}), 400
        
        if collection.find_one({"user_id": new_user_id}):
            return jsonify({"error": "User ID already exists"}), 400

        # Store in MongoDB
        new_user = {
            "user_id": new_user_id,
            "name": new_user_name,
            "interests": new_interests
        }
        collection.insert_one(new_user)
        
        # Reinitialize FAISS with updated data
        initialize_faiss()
        
        # Get recommendations for the new user
        recommendations = recommend_users(new_user_id, top_n=3)
        
        return jsonify({
            "message": "User added successfully!",
            "recommendations": recommendations
        })
    
    except Exception as e:
        print(f"Error in add_user: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/recommend", methods=["POST"])
def recommend():
    data = request.json
    target_user_id = data.get("user_id")

    recommendations = recommend_users(target_user_id, top_n=3)
    return jsonify({"recommendations": recommendations})

if __name__ == "__main__":
    app.run(debug=True)
