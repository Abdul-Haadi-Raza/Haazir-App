from firebase_admin import firestore
import uuid
import datetime

class BookerAgent:
    def __init__(self):
        self.db = firestore.client()

    def create_booking(self, booking_data: dict) -> str:
        """
        Creates a booking inside the Customer's sub-collection for better organization.
        Path: Users/{customer_id}/Bookings/{booking_id}
        """
        booking_id = str(uuid.uuid4())
        customer_id = booking_data.get("customer_id", "anonymous")
        
        # Determine initial status (usually 'active' for new bookings)
        status = booking_data.get("status", "active")

        booking_record = {
            "booking_id": booking_id,
            "status": status,
            "created_at": datetime.datetime.utcnow().isoformat(),
            **booking_data
        }
        
        # Save to User's private bookings sub-collection
        doc_ref = self.db.collection("Users").document(customer_id).collection("Bookings").document(booking_id)
        doc_ref.set(booking_record)

        # Also maintain a global collection for the Provider to see their assigned jobs
        # Path: ProviderJobs/{provider_id}/Jobs/{booking_id}
        provider_id = booking_data.get("provider_id")
        if provider_id:
            self.db.collection("ProviderJobs").document(provider_id).collection("Jobs").document(booking_id).set(booking_record)

        return booking_id

    def update_booking_status(self, customer_id: str, booking_id: str, new_status: str):
        """
        Updates status to 'completed' or 'cancelled'
        """
        # Update in Customer's list
        cust_ref = self.db.collection("Users").document(customer_id).collection("Bookings").document(booking_id)
        cust_ref.update({"status": new_status})

        # If possible, update in Provider's list too (linked via data)
        # This can be expanded based on provider notification needs
        print(f"DEBUG: Booking {booking_id} status updated to {new_status}")

    def log_chat_history(self, user_id: str, chat_history: list):
        chat_id = str(uuid.uuid4())
        chat_ref = self.db.collection("Users").document(user_id).collection("ChatLogs").document(chat_id)

        chat_record = {
            "chat_id": chat_id,
            "timestamp": datetime.datetime.utcnow().isoformat(),
            "messages": chat_history
        }

        chat_ref.set(chat_record)
