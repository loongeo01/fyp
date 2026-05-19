import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore
import requests
import io
import time
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import os
from dotenv import load_dotenv

# This line magically finds your .env file and loads the variables into os.environ
# If the .env file doesn't exist (like on GitHub Actions), it just quietly skips it!
load_dotenv() 

# Now we fetch the key. 
# Locally, it grabs it from the .env file. On GitHub, it grabs it from GitHub Secrets!
api_key = os.environ.get("googleApiKey")

if not api_key:
    raise ValueError("Google API Key is missing!")

#  Setup
print("Connecting to Firebase...")
cred = credentials.Certificate('firebase_admin_key.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Extract
print("Setting up connection to government servers...")

retry_strategy = Retry(
    total=5,
    backoff_factor=2,
    status_forcelist=[429, 500, 502, 503, 504],
    raise_on_status=False
)

adapter = HTTPAdapter(max_retries=retry_strategy)
session = requests.Session()
session.mount("https://", adapter)
session.mount("http://", adapter)

session.headers.update({
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
})


url_prices = 'https://storage.data.gov.my/pricecatcher/pricecatcher_2026-04.parquet' 
url_items = 'https://storage.data.gov.my/pricecatcher/lookup_item.csv'
url_premises = 'https://storage.data.gov.my/pricecatcher/lookup_premise.csv'

print("Fetching prices...")
try:
    response_prices = session.get(url_prices, timeout=60)
    response_prices.raise_for_status()
    prices_df = pd.read_parquet(io.BytesIO(response_prices.content))
    print("✓ Prices loaded.")
except Exception as e:
    print(f"CRITICAL ERROR: {e}")
    exit()

print("Fetching lookup files...")
items_df = pd.read_csv(io.StringIO(session.get(url_items).text))
premises_df = pd.read_csv(io.StringIO(session.get(url_premises).text))

# Transform
print("Applying ingredient filters...")

INGREDIENT_MAP = {
    "BAWANG MERAH": "BAWANG KECIL MERAH BIASA IMPORT (INDIA)",
    "BAWANG BESAR": "BAWANG BESAR KUNING/HOLLAND",
    "BAWANG PUTIH": "BAWANG PUTIH IMPORT (CHINA)",
    "HALIA": "HALIA BASAH (TUA)",
    "SERAI": "SERAI",
    "LENGKUAS": "LENGKUAS",
    "TOMATO": "TOMATO",
    "LOBAK MERAH": "LOBAK MERAH",
    "SAWI": "SAWI HIJAU",
    "KOBIS": "KUBIS BULAT (TEMPATAN)",
    "TIMUN": "TIMUN",
    "TERUNG": "TERUNG PANJANG",
    "CILI MERAH": "CILI MERAH - KULAI",
    "CILI PADI": "CILI API/PADI HIJAU",
    "UBI KENTANG": "UBI KENTANG RUSSET",
    "BROKOLI": "BROKOLI",
    "AYAM": "AYAM BERSIH - STANDARD",
    "DAGING": "DAGING LEMBU IMPORT (BLOCK)",
    "TELUR": "TELUR AYAM GRED A",
    "IKAN KEMBUNG": "IKAN KEMBUNG (ANTARA 8 HINGGA 12 EKOR SEKILOGRAM)",
    "IKAN SIAKAP": "IKAN SIAKAP (ANTARA 2 HINGGA 4 EKOR SEKILOGRAM)",
    "UDANG": "UDANG PUTIH BESAR (ANTARA 20 HINGGA 30 EKOR SEKILOGRAM)",
    "SOTONG": "SOTONG (≥ 6 EKOR SEKILOGRAM)",
    "IKAN BILIS": "IKAN BILIS GRED B (KOPEK)",
    "BERAS": "BERAS SUPER CAP RAMBUTAN 5% (IMPORT)",
    "MINYAK MASAK": "MINYAK MASAK TULEN CAP SAJI",
    "GULA": "GULA PUTIH BERTAPIS KASAR (PELBAGAI JENAMA)",
    "TEPUNG GANDUM": "TEPUNG GANDUM GP (BERBUNGKUS) PELBAGAI JENAMA",
    "SANTAN": "SANTAN KELAPA SEGAR (BIASA)",
    "GARAM": "GARAM HALUS BIASA (PELBAGAI JENAMA)",
    "KICAP MANIS": "KICAP LEMAK MANIS CAP KIPAS UDANG",
    "SOS TIRAM": "SOS TIRAM MAGGI",
    "CILI KERING": "CILI KERING KERINTING (BERTANGKAI/TIDAK BERTANGKAI)",
    "SERBUK KUNYIT": "SERBUK KUNYIT BABAS",
    "SERBUK KARI AYAM": "SERBUK KARI AYAM DAN DAGING ADABI",
}

# Automatically extract the DOSM names
target_items = list(INGREDIENT_MAP.values())

merged_df = prices_df.merge(items_df, on='item_code').merge(premises_df, on='premise_code')

target_states = ['Selangor', 'W.P. Kuala Lumpur']
target_stores = ['LOTUS', 'AEON BIG', 'KK']
store_pattern = '|'.join(target_stores)

filtered_df = merged_df[
    (merged_df['state'].isin(target_states)) & 
    (merged_df['premise'].str.contains(store_pattern, case=False, na=False)) & 
    (merged_df['item'].isin(target_items))
].copy()

# Google
GOOGLE_API_KEY = "AIzaSyAzZAR9FwfPrmNnbwkYSU4ao65St-0vzgA"

def get_google_gps(store_name, address, state):
    clean_address = str(address).replace(',,', ',').strip()
    if clean_address.endswith(','):
        clean_address = clean_address[:-1]
        
    search_text = f"{clean_address}, {state}, Malaysia"
    url = "https://maps.googleapis.com/maps/api/geocode/json"
    params = {"address": search_text, "key": GOOGLE_API_KEY}
    
    try:
        response = session.get(url, params=params, timeout=10)
        data = response.json()
        if data['status'] == 'OK':
            location = data['results'][0]['geometry']['location']
            return location['lat'], location['lng']
    except Exception as e:
        print(f"  -> Error geocoding {store_name}: {e}")
    return 0.0, 0.0

# Data Grouping
print(f"Extracting prices for {len(target_items)} items across target branches...")

branch_prices = filtered_df.groupby(
    ['premise_code', 'premise', 'state', 'district', 'address', 'item', 'unit'] 
)['price'].mean().reset_index()

stores_dict = {}
total_stores = len(branch_prices['premise_code'].unique())
current_store = 1

for index, row in branch_prices.iterrows():
    p_code = str(row['premise_code'])
    item_name = row['item']
    price = round(row['price'], 2)
    
    
    unit_val = str(row['unit']) 
    
    if p_code not in stores_dict:
        print(f"Locating store {current_store}/{total_stores}: {row['premise']}...")
        real_lat, real_lng = get_google_gps(row['premise'], row['address'], row['state'])
        time.sleep(0.2) 
        
        stores_dict[p_code] = {
            'name': row['premise'],       
            'state': row['state'],
            'district': row['district'],  
            'address': row['address'],    
            'lat': real_lat,
            'lng': real_lng,
            'prices': {}                  
        }
        current_store += 1
        
   
    stores_dict[p_code]['prices'][item_name] = {
        'price': price,
        'unit': unit_val
    }

# Loading
print("Uploading to Firebase...")
stores_collection = db.collection('stores')
upload_count = 0

for p_code, store_data in stores_dict.items():
    if store_data['lat'] != 0.0:
        try:
            stores_collection.document(p_code).set(store_data, merge=True)
            upload_count += 1
        except:
            pass

print(f"SUCCESS! {upload_count} stores updated with {len(target_items)} possible ingredients.")

