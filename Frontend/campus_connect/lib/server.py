from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_pymongo import PyMongo
from flask_bcrypt import Bcrypt
from bson import ObjectId
import datetime
from transformers import pipeline, AutoTokenizer, AutoModelForSequenceClassification
import torch

app = Flask(__name__)
CORS(app)

app.config["MONGO_URI"] = "mongodb+srv://v:viswa123@cluster0.dhc4mq5.mongodb.net/CampusConnect?retryWrites=true&w=majority"
mongo = PyMongo(app)
bcrypt = Bcrypt(app)
SECRET_KEY = "c9e4507fb83fc7b043ab36b702cd466afdcdbd98c14a43a817cabc72847b7392"

print("Loading the toxicity classifier...")
try:
    model_name = "unitary/toxic-bert"
    model = AutoModelForSequenceClassification.from_pretrained(model_name)
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    toxicity_classifier = pipeline("text-classification", 
                                 model=model, 
                                 tokenizer=tokenizer,
                                 framework="pt")
    print("Toxicity classifier loaded successfully!")
except Exception as e:
    print(f"Error loading toxicity classifier: {e}")
    raise

def classify_toxicity(text):
    try:
        result = toxicity_classifier(text)
        score = result[0]['score']

        if score < 0.3:
            label = "Neutral"
        elif score < 0.7:
            label = "Mildly Toxic"
        else:
            label = "Severely Toxic"

        return {"label": label, "score": float(score)}
    except Exception as e:
        print(f"Error in classification: {e}")
        return None

def init_db():
    try:
        # Create collections if they don't exist
        if "students" not in mongo.db.list_collection_names():
            mongo.db.create_collection("students")
            
        if "public_chat" not in mongo.db.list_collection_names():
            mongo.db.create_collection("public_chat")
            
        if "reported_messages" not in mongo.db.list_collection_names():
            mongo.db.create_collection("reported_messages")
            
        if "event_admins" not in mongo.db.list_collection_names():
            mongo.db.create_collection("event_admins")
            
        if "events" not in mongo.db.list_collection_names():
            mongo.db.create_collection("events")
            
        if "participants" not in mongo.db.list_collection_names():
            mongo.db.create_collection("participants")
        
        # Create indexes
        mongo.db.students.create_index([("email", 1)], unique=True)
        mongo.db.students.create_index([("roll_no", 1)], unique=True)
        mongo.db.event_admins.create_index([("email", 1)], unique=True)
        
    except Exception as e:
        print(f"Error initializing database: {e}")

@app.route("/register", methods=["POST"])
def register():
    try:
        data = request.json
        name = data.get("name")
        email = data.get("email")
        password = data.get("password")
        roll_no = data.get("roll_no")
        
        if not all([name, email, password, roll_no]):
            return jsonify({"error": "All fields are required"}), 400
        
        existing_student = mongo.db.students.find_one({
            "$or": [
                {"email": email},
                {"roll_no": roll_no}
            ]
        })
        
        if existing_student:
            return jsonify({"error": "Student already exists"}), 400
        
        hashed_password = bcrypt.generate_password_hash(password).decode("utf-8")
        
        student_data = {
            "name": name,
            "email": email,
            "roll_no": roll_no,
            "password": hashed_password,
            "created_at": datetime.datetime.utcnow()
        }
        
        result = mongo.db.students.insert_one(student_data)
        
        return jsonify({
            "message": "Student registered successfully",
            "student_id": str(result.inserted_id)
        }), 201
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/login", methods=["POST"])
def login():
    try:
        data = request.json
        email = data.get("email")
        password = data.get("password")
        
        if not email or not password:
            return jsonify({"error": "Email and password required"}), 400
        
        student = mongo.db.students.find_one({"email": email})
        
        if not student or not bcrypt.check_password_hash(student["password"], password):
            return jsonify({"error": "Invalid credentials"}), 401
        
        return jsonify({
            "message": "Login successful",
            "student_id": str(student["_id"])
        }), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/get_student/<student_id>", methods=["GET"])
def get_student(student_id):
    try:
        student = mongo.db.students.find_one({"_id": ObjectId(student_id)})

        if not student:
            return jsonify({"error": "Student not found"}), 404

        return jsonify({
            "student_id": str(student["_id"]),
            "name": student["name"],
            "email": student["email"],
            "roll_no": student["roll_no"],
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/send_message", methods=["POST"])
def send_message():
    try:
        data = request.json
        sender_id = data.get("sender_id")
        sender_name = data.get("sender_name")
        message = data.get("message")

        if not sender_id or not sender_name or not message:
            return jsonify({"error": "All fields are required"}), 400

        # Check message toxicity
        toxicity_result = classify_toxicity(message)
        
        message_data = {
            "sender_id": sender_id,
            "sender_name": sender_name,
            "message": message,
            "created_at": datetime.datetime.utcnow(),
            "toxicity": toxicity_result
        }

        # Store the message
        mongo.db.public_chat.insert_one(message_data)

        # If message is toxic, automatically report it
        if toxicity_result and toxicity_result["label"] in ["Mildly Toxic", "Severely Toxic"]:
            # Add to reported messages
            existing_report = mongo.db.reported_messages.find_one({"user_id": sender_id})

            if existing_report:
                mongo.db.reported_messages.update_one(
                    {"user_id": sender_id},
                    {
                        "$inc": {"report_count": 1},
                        "$push": {
                            "messages": {
                                "message": message,
                                "reported_at": datetime.datetime.utcnow(),
                                "toxicity_score": toxicity_result["score"],
                                "toxicity_label": toxicity_result["label"]
                            }
                        }
                    }
                )
            else:
                report_data = {
                    "user_id": sender_id,
                    "report_count": 1,
                    "messages": [{
                        "message": message,
                        "reported_at": datetime.datetime.utcnow(),
                        "toxicity_score": toxicity_result["score"],
                        "toxicity_label": toxicity_result["label"]
                    }],
                    "first_reported_at": datetime.datetime.utcnow()
                }
                mongo.db.reported_messages.insert_one(report_data)

            return jsonify({
                "message": "Message sent but flagged as toxic",
                "toxicity": toxicity_result
            }), 201

        return jsonify({
            "message": "Message sent successfully",
            "toxicity": toxicity_result
        }), 201

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/get_messages", methods=["GET"])
def get_messages():
    try:
        messages = list(mongo.db.public_chat.find().sort("created_at", 1))

        formatted_messages = []
        for msg in messages:
            formatted_messages.append({
                "id": str(msg["_id"]),
                "sender_id": msg["sender_id"],
                "sender_name": msg["sender_name"],
                "message": msg["message"],
                "timestamp": msg["created_at"].isoformat(),
                "toxicity": msg.get("toxicity", {"label": "Unknown", "score": 0.0})
            })

        return jsonify({"messages": formatted_messages}), 200

    except Exception as e:
        print(f"Error fetching messages: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/report_message", methods=["POST"])
def report_message():
    try:
        data = request.json
        reported_user_id = data.get("user_id")
        reported_message = data.get("message")

        if not reported_user_id or not reported_message:
            return jsonify({"error": "User ID and message are required"}), 400

        existing_report = mongo.db.reported_messages.find_one({"user_id": reported_user_id})

        if existing_report:
            mongo.db.reported_messages.update_one(
                {"user_id": reported_user_id},
                {
                    "$inc": {"report_count": 1},
                    "$push": {"messages": {"message": reported_message, "reported_at": datetime.datetime.utcnow()}}
                }
            )
        else:
            report_data = {
                "user_id": reported_user_id,
                "report_count": 1,
                "messages": [{"message": reported_message, "reported_at": datetime.datetime.utcnow()}],
                "first_reported_at": datetime.datetime.utcnow()
            }
            mongo.db.reported_messages.insert_one(report_data)

        return jsonify({"message": "Message reported successfully"}), 201

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/get_reported_messages", methods=["GET"])
def get_reported_messages():
    try:
        reported_messages = list(mongo.db.reported_messages.find().sort("first_reported_at", -1))
        formatted_reports = []

        for report in reported_messages:
            user = mongo.db.students.find_one({"_id": ObjectId(report["user_id"])})
            formatted_reports.append({
                "user_id": report["user_id"],
                "user_name": user["name"] if user else "Unknown User",
                "email": user["email"] if user else "Unknown Email",
                "report_count": report["report_count"],
                "messages": report["messages"],  # List of reported messages with timestamps
                "first_reported_at": report["first_reported_at"].isoformat(),
            })

        return jsonify({"reported_users": formatted_reports}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Event Admin Routes
@app.route("/register_event_admin", methods=["POST"])
def register_event_admin():
    try:
        data = request.get_json()
        email = data.get("email")
        password = data.get("password")

        if not email or not password:
            return jsonify({"error": "Email and password are required"}), 400

        # Check if admin already exists
        existing_admin = mongo.db.event_admins.find_one({"email": email})
        if existing_admin:
            return jsonify({"error": "Email already registered"}), 400

        # Hash the password using bcrypt
        hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')
        
        admin_data = {
            "email": email,
            "password": hashed_password,
            "created_at": datetime.datetime.now().isoformat(),
            "events": []  # Initialize empty events list
        }

        mongo.db.event_admins.insert_one(admin_data)
        return jsonify({"message": "Event admin registered successfully"}), 201

    except Exception as e:
        app.logger.error(f"Error registering event admin: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/login_event_admin", methods=["POST"])
def login_event_admin():
    try:
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')

        if not email or not password:
            return jsonify({'error': 'Email and password are required'}), 400

        # Find the admin
        admin = mongo.db.event_admins.find_one({'email': email})
        if not admin:
            return jsonify({'error': 'Admin not found'}), 404

        # Verify password using bcrypt
        if not bcrypt.check_password_hash(admin['password'], password):
            return jsonify({'error': 'Invalid password'}), 401

        # Get event IDs from admin document
        event_ids = admin.get('events', [])
        
        # Fetch events for this admin using event IDs
        events = list(mongo.db.events.find({'event_id': {'$in': event_ids}}))
        
        # Convert ObjectId to string for JSON serialization
        for event in events:
            event['_id'] = str(event['_id'])

        return jsonify({
            'message': 'Login successful',
            'events': events
        }), 200

    except Exception as e:
        app.logger.error(f"Error in admin login: {str(e)}")
        return jsonify({'error': f'Internal server error: {str(e)}'}), 500

# Event Management Routes
@app.route('/create_event', methods=['POST'])
def create_event():
    try:
        data = request.get_json()
        
        # Required fields
        event_name = data.get('event_name')
        start_date = data.get('start_date')
        end_date = data.get('end_date')
        organized_by = data.get('organized_by')
        description = data.get('description')
        pricing = data.get('pricing')
        admin_email = data.get('admin_email')
        
        if not all([event_name, start_date, end_date, organized_by, description, pricing, admin_email]):
            return jsonify({'error': 'Missing required fields'}), 400
        
        # Generate a new event ID
        event_id = str(ObjectId())
        
        event = {
            'event_id': event_id,
            'event_name': event_name,
            'start_date': start_date,
            'end_date': end_date,
            'organized_by': organized_by,
            'description': description,
            'pricing': pricing,
            'admin_email': admin_email,
            'created_at': datetime.datetime.now().isoformat(),
            'registrations': []
        }
        
        # Insert the event
        mongo.db.events.insert_one(event)
        
        # Update the admin's events list
        mongo.db.event_admins.update_one(
            {'email': admin_email},
            {'$push': {'events': event_id}}
        )
        
        # Remove the ObjectId before sending response
        event['_id'] = str(event.get('_id', ''))
        
        return jsonify({
            'message': 'Event created successfully',
            'event': event
        }), 201
            
    except Exception as e:
        app.logger.error(f"Error creating event: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/get_events', methods=['GET'])
def get_events():
    try:
        # Fetch all events
        events = list(mongo.db.events.find())
        
        # Convert ObjectId to string for JSON serialization
        for event in events:
            event['_id'] = str(event['_id'])
            
        return jsonify({
            'events': events,
            'message': 'Events fetched successfully'
        }), 200
        
    except Exception as e:
        app.logger.error(f"Error fetching events: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/get_admin_events/<admin_email>', methods=['GET'])
def get_admin_events(admin_email):
    try:
        # Find the admin and their event IDs
        admin = mongo.db.event_admins.find_one({'email': admin_email})
        if not admin:
            return jsonify({'error': 'Admin not found'}), 404
            
        event_ids = admin.get('events', [])
        
        # Find all events for this admin using the event IDs
        events = list(mongo.db.events.find({'event_id': {'$in': event_ids}}))
        
        # Convert ObjectId to string for JSON serialization
        for event in events:
            event['_id'] = str(event['_id'])
            
        return jsonify({
            'events': events,
            'message': 'Events fetched successfully'
        }), 200
        
    except Exception as e:
        app.logger.error(f"Error fetching admin events: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route("/get_registered_participants/<event_id>", methods=["GET"])
def get_registered_participants(event_id):
    try:
        participants = list(mongo.db.participants.find({"event_id": event_id}))

        formatted_participants = [{
            "participant_id": str(p["_id"]),
            "name": p.get("name"),
            "email": p.get("email"),
            "registered_at": p.get("registered_at").isoformat() if p.get("registered_at") else None
        } for p in participants]

        return jsonify({"participants": formatted_participants}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/register_event/<event_id>', methods=['POST'])
def register_event(event_id):
    try:
        data = request.get_json()
        name = data.get('name')
        email = data.get('email')
        roll_no = data.get('roll_no')
        
        if not all([name, email, roll_no]):
            return jsonify({'error': 'Missing required fields'}), 400
            
        # Check if event exists
        event = mongo.db.events.find_one({'event_id': event_id})
        if not event:
            return jsonify({'error': 'Event not found'}), 404
            
        # Check if user is already registered
        if any(reg.get('email') == email for reg in event.get('registrations', [])):
            return jsonify({'error': 'You are already registered for this event'}), 400
            
        registration = {
            'name': name,
            'email': email,
            'roll_no': roll_no,
            'registered_at': datetime.datetime.now().isoformat()
        }
        
        # Add registration to event
        mongo.db.events.update_one(
            {'event_id': event_id},
            {'$push': {'registrations': registration}}
        )
        
        return jsonify({
            'message': 'Registration successful',
            'registration': registration
        }), 200
        
    except Exception as e:
        app.logger.error(f"Error registering for event: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/get_event_registrations/<event_id>', methods=['GET'])
def get_event_registrations(event_id):
    try:
        # Find the event
        event = mongo.db.events.find_one({'event_id': event_id})
        if not event:
            return jsonify({'error': 'Event not found'}), 404
            
        # Get registrations from the event
        registrations = event.get('registrations', [])
            
        return jsonify({
            'registrations': registrations,
            'message': 'Registrations fetched successfully'
        }), 200
        
    except Exception as e:
        app.logger.error(f"Error fetching event registrations: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/get_registered_events/<email>', methods=['GET'])
def get_registered_events(email):
    try:
        # Find all events where this email is registered
        events = mongo.db.events.find({
            'registrations': {
                '$elemMatch': {
                    'email': email
                }
            }
        })
        
        registered_events = []
        for event in events:
            event_data = {
                'event_id': event['event_id'],
                'event_name': event['event_name'],
                'description': event['description'],
                'start_date': event['start_date'],
                'organized_by': event['organized_by'],
                'pricing': event.get('pricing', 'Free'),
                'attendance_marked': False  # Default to False
            }
            
            # Check if attendance is marked for this user
            for registration in event.get('registrations', []):
                if registration['email'] == email:
                    event_data['attendance_marked'] = registration.get('attendance_marked', False)
                    break
                    
            registered_events.append(event_data)
            
        return jsonify({'events': registered_events}), 200
        
    except Exception as e:
        app.logger.error(f"Error fetching registered events: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

# Initialize the application
if __name__ == "__main__":
    init_db()  
    app.run(host="0.0.0.0", debug=True)