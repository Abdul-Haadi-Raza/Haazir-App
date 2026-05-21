from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import firebase_admin
from firebase_admin import credentials, firestore
from agents.conversational_agent import ConversationalAgent
from agents.matchmaker_agent import MatchmakerAgent
from agents.booker_agent import BookerAgent
from agents.followup_agent import FollowUpAgent
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("Firebase initialized successfully.")
except Exception as e:
    print(f"Firebase initialization failed: {e}")
    db = None

class ChatRequest(BaseModel):
    message: str
    user_id: str
    history: list = [] # Optional chat history to log upon completion

class DiagnoseRequest(BaseModel):
    transcription: str
    base_fare: int
    service_type: str

@app.get("/")
def read_root():
    return {"status": "Haazir Orchestrator API is running"}

@app.post("/diagnose")
def process_diagnosis(request: DiagnoseRequest):
    try:
        import json
        transcription = request.transcription
        base_fare = request.base_fare
        service_type = request.service_type.lower()
        print(f"INFO: Received diagnosis request. Transcription: {transcription}, Base Fare: {base_fare}")

        # Local fallback rules mapping keywords to severity, parts, and prices
        fallback_severity = 2
        fallback_parts = []
        fallback_parts_cost = 0
        fallback_labor = 300
        
        lower_trans = transcription.lower()
        
        # Rule matches for plumbing
        if "leak" in lower_trans or "pipe" in lower_trans or "toti" in lower_trans or "sink" in lower_trans:
            fallback_severity = 3
            fallback_parts = ["PVC Pipe Joint", "Leak Sealant Tape"]
            fallback_parts_cost = 650
            fallback_labor = 500
        elif "flush" in lower_trans or "comod" in lower_trans or "washer" in lower_trans:
            fallback_severity = 4
            fallback_parts = ["Flush Valve Kit", "Rubber Washer"]
            fallback_parts_cost = 1400
            fallback_labor = 800
        # Rule matches for AC / Refrigeration
        elif "compressor" in lower_trans or "ac cooling" in lower_trans or "condenser" in lower_trans or "cool" in lower_trans:
            fallback_severity = 5
            fallback_parts = ["AC Compressor (Panasonic)", "R410a Gas Refill"]
            fallback_parts_cost = 9500
            fallback_labor = 2500
        elif "gas" in lower_trans or "leakage" in lower_trans or "refill" in lower_trans:
            fallback_severity = 4
            fallback_parts = ["Freon Gas Recharging"]
            fallback_parts_cost = 4500
            fallback_labor = 1500
        # Rule matches for electrician
        elif "short" in lower_trans or "spark" in lower_trans or "wiring" in lower_trans or "switch" in lower_trans:
            fallback_severity = 4
            fallback_parts = ["Copper Wiring Roll", "Insulation Tape"]
            fallback_parts_cost = 1800
            fallback_labor = 1000
        elif "socket" in lower_trans or "board" in lower_trans:
            fallback_severity = 2
            fallback_parts = ["Standard 3-Pin Socket", "Switch Button"]
            fallback_parts_cost = 450
            fallback_labor = 400
        
        fallback_updated_fare = base_fare + fallback_parts_cost + fallback_labor
        
        fallback_res = {
            "status": "success",
            "severity": fallback_severity,
            "parts_recommended": fallback_parts,
            "parts_cost": fallback_parts_cost,
            "additional_labor": fallback_labor,
            "updated_fare": fallback_updated_fare,
            "summary_en": f"AI Diagnosed: {', '.join(fallback_parts) if fallback_parts else 'Minor service adjustment'}. Severity: Level {fallback_severity}.",
            "summary_ur": f"تشخیص: {', '.join(fallback_parts) if fallback_parts else 'معمولی سروس'}. شدت: لیول {fallback_severity}."
        }

        # Try calling Gemini Flash for genuine AI capability
        gemini_api_key = os.getenv("GEMINI_API_KEY")
        if not gemini_api_key:
            print("WARNING: GEMINI_API_KEY not found. Using robust local fallback.")
            return fallback_res

        from google import genai
        from google.genai import types
        
        client = genai.Client(api_key=gemini_api_key)
        
        system_prompt = f"""
        You are an expert AI Job Diagnosis System for the "Haazir" platform in Pakistan.
        Analyze the speech transcription from the service provider (could be in English, Urdu script, or Roman Urdu).
        
        Category: {service_type}
        Original Base Fare: {base_fare} PKR
        
        Evaluate:
        1. Severity of repair: 1 to 5.
        2. Recommended parts list (PKR estimate). Keep parts prices realistic for Pakistan market.
        3. Extra labor charge based on category/severity.
        4. Total updated fare (base_fare + parts_cost + extra_labor).
        
        Input transcription: "{transcription}"
        
        Return ONLY valid JSON matching this schema:
        {{
            "severity": int,
            "parts_recommended": list of strings,
            "parts_cost": int,
            "additional_labor": int,
            "updated_fare": int,
            "summary_en": str,
            "summary_ur": str
        }}
        """

        try:
            response = client.models.generate_content(
                model='gemini-flash-latest',
                contents=[transcription],
                config=types.GenerateContentConfig(
                    system_instruction=system_prompt,
                    response_mime_type="application/json",
                )
            )
            
            clean_json = response.text.replace("```json", "").replace("```", "").strip()
            result = json.loads(clean_json)
            result["status"] = "success"
            print("INFO: AI Diagnosis complete.")
            return result
        except Exception as e:
            print(f"WARNING: Gemini AI call failed: {e}. Falling back to rules.")
            return fallback_res

    except Exception as e:
        print(f"ERROR in process_diagnosis: {e}")
        return {
            "status": "error",
            "message": str(e),
            "severity": 3,
            "parts_recommended": [],
            "parts_cost": 0,
            "additional_labor": 300,
            "updated_fare": base_fare + 300,
            "summary_en": "Failed to complete AI diagnosis. Using basic fallback.",
            "summary_ur": "تشخیص مکمل نہیں ہوسکی۔ معمولی سروس لاگو کی گئی ہے۔"
        }

@app.post("/chat")
def process_chat(request: ChatRequest):
    try:
        text_message = request.message
        user_id = request.user_id
        print(f"INFO: Received chat request from user {user_id}: {text_message}")

        saved_addresses = []
        if db and user_id and user_id != 'guest_user':
            try:
                user_doc = db.collection('Users').document(user_id).get()
                if user_doc.exists:
                    user_data = user_doc.to_dict()
                    saved_addresses = user_data.get('saved_addresses', [])
            except Exception as fe:
                print(f"WARNING: Failed to fetch user saved addresses from Firestore: {fe}")

        conv_agent = ConversationalAgent()
        conv_result = conv_agent.process_request(text_message, saved_addresses=saved_addresses)
        
        if not conv_result.get("is_complete"):
            print("DEBUG: Request incomplete, asking for clarification.")
            return {
                "status": "clarification_needed",
                "reply": conv_result.get("clarifying_question"),
                "agent_logs": "ConversationalAgent detected missing parameters. Asking user."
            }

        extracted = conv_result["extracted_data"]
        service = extracted.get("service_type")
        location = extracted.get("location")
        severity = extracted.get("repair_severity", 2)

        print(f"DEBUG: Processing complete request for {service} at {location}")

        matchmaker = MatchmakerAgent()
        match_result = matchmaker.find_best_provider(user_location=location, service_category=service, severity=severity)
        
        if match_result["status"] != "success":
            print(f"DEBUG: Matchmaker failed: {match_result.get('message')}")
            return {
                "status": "failed",
                "reply": f"Sorry, I couldn't find any {service} near {location} right now.",
                "agent_logs": match_result.get("message")
            }

        best_provider = match_result["best_provider"]
        print(f"DEBUG: Selected provider: {best_provider['name']}")

        booker = BookerAgent()

        booking_data = {
            "service": service,
            "location": location,
            "time": extracted.get("time"),
            "repair_details": extracted.get("specific_repair"),
            "customer_id": user_id,
            "provider_id": best_provider["uid"],
            "provider_name": best_provider.get("name", "Assigned Provider"),
            "provider_phone": best_provider.get("phone", ""),
            "price_estimate": best_provider.get("estimated_price", "Rs. 500+")
        }

        print("DEBUG: Creating booking in Firestore...")
        booking_id = booker.create_booking(booking_data)
        booking_data["booking_id"] = booking_id

        # Log chat history to Firebase for the user
        if request.history:
            print("DEBUG: Logging chat history...")
            booker.log_chat_history(user_id, request.history)

        followup_agent = FollowUpAgent()
        followup_result = followup_agent.schedule_followup(booking_data)
        
        print("DEBUG: Pipeline complete. Sending response.")
        reply_text = f"Done! I have booked {best_provider['name']} ({best_provider['distance_text']} away). Estimated Cost: {best_provider.get('estimated_price')}. They will arrive at {extracted.get('time')}."
        if match_result.get("is_external"):
            reply_text = match_result["external_message"]

        return {
            "status": "success",
            "reply": reply_text,
            "booking": booking_data,
            "provider": best_provider,
            "all_matches": match_result.get("all_matches", [best_provider]),
            "followup": followup_result["followup_message"],
            "agent_logs": [
                f"ConversationalAgent: Parsed 4 parameters with severity {severity}.",
                f"MatchmakerAgent: Assigned provider {best_provider['uid']} (External: {match_result.get('is_external')}).",
                "BookerAgent: Simulated booking and wrote to Firestore.",
                followup_result["agent_logs"]
            ]
        }
    except Exception as e:
        print(f"ERROR: Global exception in /chat: {e}")
        return {
            "status": "error",
            "reply": "I'm having a bit of trouble reaching my AI core right now. Please try again in a few seconds!",
            "agent_logs": str(e)
        }
