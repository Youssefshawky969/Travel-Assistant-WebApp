import requests
from flask import Flask, request, jsonify
from flask_cors import CORS
from mangum import Mangum
from asgiref.wsgi import WsgiToAsgi
from datetime import datetime


def get_coordinates(city):
    """Get latitude and longitude from city name using OpenStreetMap's Nominatim API."""
    geo_url = f"https://nominatim.openstreetmap.org/search?q={city}&format=json"
    headers = {
        "User-Agent": "SmartTravelAssistant/1.0 (yshawky757@gmail.com)"
    }
    response = requests.get(geo_url, headers=headers)

    print("OpenStreetMap Response:", response.text)

    if response.status_code == 200:
        try:
            data = response.json()
            if data and len(data) > 0:
                return float(data[0]["lat"]), float(data[0]["lon"])
        except Exception as e:
            print("Error parsing JSON:", str(e))
    
    return None, None

def get_weather(city):
    """Get weather data for a given city."""
    lat, lon = get_coordinates(city)
    if lat is None or lon is None:
        return f"Could not find location: {city}"

    weather_url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&hourly=temperature_2m&timezone=auto"
    response = requests.get(weather_url)

    if response.status_code == 200:
        try:
            data = response.json()
            print("Weather API Response:", data)  # Debugging output

            if "hourly" in data and "temperature_2m" in data["hourly"]:
                temperature_list = data["hourly"]["temperature_2m"]
                timestamps = data["hourly"]["time"]  # Get corresponding timestamps

                # Find the latest temperature based on the current time
                current_time = datetime.utcnow().isoformat(timespec='seconds')
                
                # Find the closest matching timestamp
                closest_index = min(range(len(timestamps)), key=lambda i: abs(datetime.fromisoformat(timestamps[i]) - datetime.utcnow()))
                latest_temperature = temperature_list[closest_index]

                return f"Current temperature in {city} is {latest_temperature:.1f} celsius "

        except Exception as e:
            return f"Error processing weather data: {str(e)}"
    
    return "Error fetching weather data."

def get_tourist_places(city):
    API_KEY = "AIzaSyCaGxnm8GLBY4XdpymMazPcAq8qfmpz0bQ"  
    url = f"https://maps.googleapis.com/maps/api/place/textsearch/json?query=tourist+attractions+in+{city}&key={API_KEY}"

    response = requests.get(url)
    data = response.json()

    if "results" in data:
        places = []
        for place in data["results"][:5]:  # نأخذ أول 5 أماكن فقط
            places.append({
                "name": place["name"],
                "rating": place.get("rating", "No rating available")
            })
        return places
    else:
        return None
    

def get_city_info(city):
    """
    Combines weather and tourist places information for a given city.
    """
    # Get weather data
    weather = get_weather(city)
    
    # Get tourist attractions
    places = get_tourist_places(city)

    # Create a response dictionary
    result = {
        "city": city,
        "weather": weather,  # Weather function already returns a formatted string
        "tourist_places": []
    }

    # If places were found, add them to the result
    if places:
        result["tourist_places"] = places
    else:
        result["tourist_places"] = ["No tourist attractions found."]

    return result




# Flask API Route
app = Flask(__name__)
CORS(app)

@app.route('/get_city_info', methods=['GET'])
def get_city_info_api():
    city = request.args.get('city')
    if city:
        info = get_city_info(city)
        return jsonify({"response": info})
    else:
        return jsonify({"error": "City parameter is required"}), 400

asgi_app = WsgiToAsgi(app)
handler = Mangum(asgi_app, lifespan="off")
