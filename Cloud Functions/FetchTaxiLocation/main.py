import firebase_admin
import json
from firebase_admin import credentials
from firebase_admin import firestore
from google.cloud import storage
from google.cloud.storage import Blob
import utm  # for latlong conversion to utm
from datetime import datetime 
import pandas as pd
import requests

# Use the application default credentials
cred = credentials.ApplicationDefault()
firebase_admin.initialize_app(cred, {
  'projectId': "potatotaxis",
})

def CalculateScore(event, context):

  db = firestore.client()

  client = storage.Client()
  bucket = client.get_bucket("potatotaxis.appspot.com")

  blob = bucket.get_blob('standLocations.json')
  standLocationJSON = json.loads(blob.download_as_text())
  standLocations = pd.DataFrame.from_dict(standLocationJSON, orient = 'index')
  blob = bucket.get_blob('standLocationsUTM.json')
  standLocationsUTMJSON = json.loads(blob.download_as_text())
  standLocationsUTM = pd.DataFrame.from_dict(standLocationsUTMJSON, orient = 'index')

  # Fetch taxi locations
  now = datetime.now()
  timeParams = {"date_time" : now.strftime("%Y-%m-%dT%H:%M:%S")}
  jsonData = requests.get("https://api.data.gov.sg/v1/transport/taxi-availability", params = timeParams).json()
  taxiLocations = pd.DataFrame(columns = ["yCoord", "xCoord"])

  for [xCoord, yCoord] in jsonData["features"][0]["geometry"]["coordinates"]:
    taxiLocations = taxiLocations.append({"xCoord" : xCoord, "yCoord" : yCoord}, ignore_index=True)

  blob = Blob('TaxiLocations.json', bucket).upload_from_string(taxiLocations.to_json(orient = 'index'), 'application/json')

  # Make new DF with UTM coordinates
  results = [utm.from_latlon(lat, long) for lat, long in zip(taxiLocations['yCoord'], taxiLocations['xCoord'])]
  taxiLocationsUTM = pd.DataFrame(results, columns =["UTM_x", "UTM_y", "zoneNum", "zoneLet"])

  # Score calculation
  count = 0
  score = []
  # compare each taxi to each stand
  for stand_row in standLocationsUTM.itertuples(index=True, name='Pandas'):
      for taxi_row in taxiLocationsUTM.itertuples(index=True, name='Pandas'):
          # if taxi is near the stand
          if taxi_row.UTM_x < stand_row.xMax and taxi_row.UTM_x > stand_row.xMin and taxi_row.UTM_y < stand_row.yMax and taxi_row.UTM_y < stand_row.yMin :
              count = count + 1
      score.append(count)
      count = 0

  # Add score to dataframe
  standLocations['Score'] = score
  standLocationDict = standLocations.to_dict(orient='index')

  for key, value in standLocationDict.items():
    db.collection(u'TaxiStand').document(str(key)).set(value)