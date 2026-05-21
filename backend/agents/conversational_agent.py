import os
import time
import json
from google import genai
from google.genai import types, errors
from dotenv import load_dotenv

load_dotenv()

class ConversationalAgent:
    def __init__(self):
        gemini_api_key = os.getenv("GEMINI_API_KEY")
        self.client = genai.Client(api_key=gemini_api_key)

    def process_request(self, user_message: str, saved_addresses: list = None, retries: int = 3) -> dict:
        if saved_addresses is None:
            saved_addresses = []

        addresses_context = ""
        if saved_addresses:
            addresses_context = "User's Saved Addresses:\n"
            for addr in saved_addresses:
                addresses_context += f"- Label: {addr.get('label')}, Physical Address: {addr.get('address')}\n"
        else:
            addresses_context = "The user has no saved addresses."

        system_prompt = f"""
        You are an intelligent Service Orchestrator for the "Haazir" platform in Pakistan.
        Your goal is to parse a user's service request.
        
        A complete request MUST contain 4 parameters:
        1. Service Type (e.g., Electrician, Plumber, AC Technician)
        2. EXACT Location (e.g., House 5, Street 10, F-8/3. Just saying 'F-8' or 'G-13' is INCOMPLETE. You must ask for house/street).
        3. Time (e.g., Now, Tomorrow morning, 5 PM)
        4. Specific Repair Detail (e.g., AC is not cooling, fan making noise, pipe is leaking)
        
        LANGUAGE SUPPORT:
        - The user may speak in English, Urdu (Arabic script), or Roman Urdu (Urdu words in English letters).
        - You must understand all three perfectly.
        - If the user uses Roman Urdu like "mujhe bijli wala chahiye", identify "Electrician".
        - If location is "ghar no 12 gali 4", extract it as "House 12, Street 4".

        SAVED ADDRESSES, TRANSLATION & CONFIRMATION PROTOCOL:
        {addresses_context}

        The user might refer to an address using a place label, possibly in Urdu or Roman Urdu (e.g., "meray ghar", "apnay ghar", "office", "daftar", "abbu ka ghar", "work", "parents house").
        
        - Step 1: Translate the place label to English:
          - "ghar", "meray ghar", "apnay ghar", "home", etc. -> "Home"
          - "office", "daftar", "work", etc. -> "Office" (or matching label in context like "Work")
          - "abbu ka ghar", "abbu k ghar", "parents home", etc. -> "Parents Home" (or matching label in context like "Parents Home" or "Abbu ka Ghar")
          - If the user specifies any other label, translate it semantically to English first.

        - Step 2: Check the translated English label against the Saved Addresses context:
          - Perform a case-insensitive semantic match between the translated label and the labels listed under "User's Saved Addresses".
          - If a match is found:
            - A. If the user's combined input history does NOT contain explicit confirmation of this address yet:
              - You must ask the user whether this is the address on which they want the service.
              - Set "is_complete" to false.
              - Set "location" to null in "extracted_data" (since it is not confirmed yet).
              - The "clarifying_question" MUST be exactly formatted as:
                "Is this the address on which you want the service? {{Label}} ka address: '{{Address}}' hai, isi par book karain? (Haan / Nahi)"
                (Replace {{Label}} with the matched English label, e.g., 'Home', and {{Address}} with the actual physical address string from the saved addresses list).
                
            - B. If the user's latest input is a confirmation ("yes", "haan", "ji", "ji haan", "bilkul", "yes please", "isi par", "agree"):
              - Resolve "location" in "extracted_data" to the physical address string of that matched saved address.
              - Set "is_complete" to true (if all other 3 parameters are present).
              - Set "clarifying_question" to null.
              
            - C. If the user's latest input is a rejection ("no", "nahi", "na", "nay"):
              - First, check if the user also provided an alternative physical address in the same turn (e.g., "Nahi, House 25, G-11" or "Nahi, Islamabad" or "Nahi, Giga Mall").
              - If an alternative address is detected in the input:
                - Extract and resolve "location" to that new physical address.
                - Set "is_complete" to true (if other parameters are present).
                - Set "clarifying_question" to null.
              - If no alternative address is detected (e.g., they just said "Nahi" or "No"):
                - Ask the user to provide their physical address.
                - Set "is_complete" to false.
                - Set "location" to null.
                - Set "clarifying_question" to a friendly prompt requesting the physical address (e.g., "Please provide the complete address where you need the service.").

          - If NO match is found for the translated label in Saved Addresses:
            - Prompt the user to provide their physical address.
            - Set "is_complete" to false.
            - Set "location" to null.
            - Set "clarifying_question" to a friendly prompt requesting their physical address.

        IMPORTANT: Your entire response MUST be a single JSON object. No conversational text before or after the JSON.
        
        IF any of the 4 parameters are MISSING (especially if the location lacks a house/street):
        - Set "is_complete" to false.
        - Set "clarifying_question" to a friendly question asking ONLY for the missing details. 
        - CRITICAL: The "clarifying_question" MUST be in the EXACT SAME LANGUAGE and script as the user's message.
        - If user spoke in Roman Urdu, respond in Roman Urdu. If in Urdu script, respond in Urdu script.
        
        IF all 4 parameters are PRESENT:
        - Set "is_complete" to true.
        - Evaluate the "repair_severity" from 1 to 3 (1 = minor like a wire/plug, 3 = major like compressor/fridge).
        - Extract the parameters in English for the backend, but use the user's context.
        
        Return ONLY valid JSON matching this schema:
        {{
            "is_complete": bool,
            "clarifying_question": str or null,
            "extracted_data": {{
                "service_type": str or null,
                "location": str or null,
                "time": str or null,
                "specific_repair": str or null,
                "repair_severity": int or null
            }}
        }}
        """

        for attempt in range(retries):
            try:
                response = self.client.models.generate_content(
                    model='gemini-flash-latest',
                    contents=[user_message],
                    config=types.GenerateContentConfig(
                        system_instruction=system_prompt,
                        response_mime_type="application/json",
                    )
                )

                print(f"DEBUG: User Message: {user_message}")
                response_text = response.text
                print(f"DEBUG: Gemini Raw Response: {response_text}")

                # Clean response text in case Gemini adds markdown code blocks
                clean_json = response_text.replace("```json", "").replace("```", "").strip()
                result = json.loads(clean_json)
                return result

            except errors.ServerError as e:
                if "503" in str(e) or "high demand" in str(e):
                    print(f"WARNING: Gemini is busy (Attempt {attempt + 1}/{retries}). Retrying in {2**attempt}s...")
                    time.sleep(2**attempt)
                    continue
                raise e
            except Exception as e:
                print(f"DEBUG: Error in ConversationalAgent: {e}")
                return {"is_complete": False, "clarifying_question": "I am having trouble processing your request right now. Could you please try again in a moment?"}

        # Fallback if all retries fail
        return {
            "is_complete": False,
            "clarifying_question": "Our AI service is currently experiencing high demand. Please wait a few seconds and send your message again so I can help you better!"
        }
