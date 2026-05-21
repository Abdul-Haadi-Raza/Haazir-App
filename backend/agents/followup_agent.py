class FollowUpAgent:
    def schedule_followup(self, booking_data: dict) -> dict:
        # In a real app, this would schedule a Cloud Task to send an FCM push notification
        # For the hackathon simulation, we just return the generated follow-up text.
        
        provider_id = booking_data.get("provider_id")
        time = booking_data.get("time")
        
        return {
            "status": "scheduled",
            "followup_message": f"Reminder: Your provider will arrive at {time}.",
            "agent_logs": f"FollowUpAgent: Scheduled FCM push notification for {time}."
        }
