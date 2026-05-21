import firebase_admin
from firebase_admin import credentials, firestore
import random

# Initialize Firebase
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
except Exception:
    pass

db = firestore.client()

CATEGORIES = ["plumber", "electrician", "ac technician", "carpenter", "painter"]

FIRST_NAMES = [
    "Muhammad", "Ahmed", "Ali", "Hamza", "Bilal", "Zubair", "Tariq", "Sajid", 
    "Yasir", "Waseem", "Kamran", "Faisal", "Nadeem", "Imran", "Arshad", "Asif",
    "Rashid", "Rizwan", "Farhan", "Babar", "Waqas", "Adnan", "Zeeshan", "Noman"
]

LAST_NAMES = [
    "Khan", "Ahmed", "Ali", "Shafiq", "Mahmood", "Rasheed", "Butt", "Iqbal", 
    "Siddiqui", "Rehman", "Abbasi", "Malik", "Chaudhry", "Javed", "Hussain", "Mughal"
]

SECTORS = {
    "F-6": (33.7297, 73.0735),
    "F-7": (33.7214, 73.0565),
    "F-8": (33.7124, 73.0425),
    "F-10": (33.6934, 73.0185),
    "F-11": (33.6845, 73.0035),
    "G-6": (33.7225, 73.0905),
    "G-7": (33.7085, 73.0755),
    "G-8": (33.6985, 73.0555),
    "G-9": (33.6895, 73.0335),
    "G-10": (33.6795, 73.0125),
    "G-11": (33.6685, 72.9982),
    "I-8": (33.6798, 73.0725),
    "I-9": (33.6685, 73.0515),
    "I-10": (33.6575, 73.0325),
    "E-7": (33.7258, 73.0385),
    "E-11": (33.6955, 72.9785),
    "H-8": (33.6785, 73.0595)
}

def generate_random_pakistani_name():
    return f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"

def seed_data():
    print("Deleting old mock data in ProviderProfiles...")
    docs = db.collection("ProviderProfiles").list_documents()
    deleted_count = 0
    for doc in docs:
        if doc.id.startswith("mock_pro_") or doc.id.startswith("seed_pro_"):
            doc.delete()
            deleted_count += 1
    print(f"Deleted {deleted_count} old mock/seeded documents.")

    print("Generating 60 provider profiles (12 per category)...")
    total_seeded = 0

    for category in CATEGORIES:
        for idx in range(1, 13):
            provider_id = f"seed_pro_{category.replace(' ', '_')}_{idx}"
            name = generate_random_pakistani_name()
            
            # Select random sector and add slight variance
            sector_name, (base_lat, base_lng) = random.choice(list(SECTORS.items()))
            lat = base_lat + random.uniform(-0.003, 0.003)
            lng = base_lng + random.uniform(-0.003, 0.003)
            
            experience = random.randint(2, 18)
            total_jobs = random.randint(20, 450)
            rating = round(random.uniform(4.2, 5.0), 1)
            
            provider_data = {
                "uid": provider_id,
                "name": name,
                "category": category,
                "phone": f"03{random.randint(10, 45)}{random.randint(1000000, 9999999)}",
                "rating": rating,
                "total_jobs": total_jobs,
                "experience": str(experience),
                "latitude": lat,
                "longitude": lng,
                "area": f"House {random.randint(1, 200)}, Street {random.randint(1, 50)}, {sector_name}, Islamabad",
                "is_verified": True,
                "verified": True,
                "is_online": True, # Matchmaker needs online? Actually matchmaker just streams categories!
                "role": "provider",
                "shop_address": f"Shop {random.randint(1, 40)}, {sector_name} Markaz, Islamabad",
                "cnic": f"37405{random.randint(10000000, 99999999)}"
            }

            db.collection("ProviderProfiles").document(provider_id).set(provider_data)
            
            # Also seed into Users collection so login works for them
            user_data = {
                "uid": provider_id,
                "name": name,
                "phone": provider_data["phone"],
                "role": "provider",
                "cnic": provider_data["cnic"],
                "shop_address": provider_data["shop_address"],
                "experience": provider_data["experience"],
                "category": category,
                "latitude": lat,
                "longitude": lng,
            }
            db.collection("Users").document(provider_id).set(user_data)
            
            print(f"Seeded: {name} as {category.title()} in {sector_name}")
            total_seeded += 1

    print(f"\nSUCCESS: Seeded {total_seeded} Providers into both Users and ProviderProfiles collections!")

if __name__ == "__main__":
    seed_data()
