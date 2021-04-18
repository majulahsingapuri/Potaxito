import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
from math import cos
from flask import Request
from flask import jsonify
from geopy.distance import geodesic

# Use the application default credentials
# cred = credentials.ApplicationDefault()
cred = credentials.Certificate('/Users/bhargav/Downloads/potatotaxis-ef187b71a10c.json')
firebase_admin.initialize_app(cred)

def FetchTaxiStandScores(request):

    #     # Set CORS headers for the preflight request
    # if request.method == 'OPTIONS':
    #     # Allows GET requests from any origin with the Content-Type
    #     # header and caches preflight response for an 3600s
    #     headers = {
    #         'Access-Control-Allow-Origin': '*',
    #         'Access-Control-Allow-Methods': 'GET, POST',
    #         'Access-Control-Allow-Headers': 'Content-Type',
    #         'Access-Control-Max-Age': '3600'
    #     }

    #     return ('', 204, headers)

    # Set CORS headers for the main request
    headers = {
        'Content-Type':'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
    }

    # # END CORS

    # requestJSON = request.get_json()
    # latitude = requestJSON['yCoord']
    # longitude = requestJSON['xCoord']
    latitude = 1.294741
    longitude = 103.850821

    #Length in meters of 1° of latitude = always 111.32 km = 111320 m
    #Length in meters of 1° of longitude = 40075 km * cos( latitude ) / 360
    y_distance = 1500/111320 #1500 metres in terms of latitude degrees
    x_distance = 1500/(40075000 * cos(latitude)/360) #~1500 metres in terms of longitude degrees

    incr_x = x_distance/2
    incr_y = y_distance/2

    min_x = longitude - incr_x
    max_x = longitude + incr_x
    min_y = latitude - incr_y
    max_y = latitude + incr_y

    db = firestore.client()
    taxi_stand_ref = db.collection(u'TaxiStand')
    docs = taxi_stand_ref.where(u'xCoord', u">=", min_x).where(u'xCoord', u"<=", max_x).stream()

    valid_docs = {}
    for doc in docs:
        docData = doc.to_dict()
        if (min_y <= docData['yCoord'] <= max_y):
            docData['Score'] += scoreFunction(geodesic((docData['yCoord'], docData['xCoord']), (latitude, longitude)).kilometers)
            valid_docs[doc.id] = docData
    
    if valid_docs != {}:
        maxStandID = -1
        maxStandScore = 0

        for standID, data in valid_docs.items():
            if data['Score'] > maxStandScore:
                maxStandID = standID
                maxStandScore = data['Score']
        
        # response = jsonify({'standID' : maxStandID, 'data' : valid_docs[maxStandID]})
        response = {'standID' : maxStandID, 'data' : valid_docs[maxStandID]}
    else:
        # response = jsonify({})
        response = {}
    
    return (response, 200, headers)

def scoreFunction(distance):
    if 0 <= distance < 0.2:
        return 75 - (250 * distance)
    elif 0.2 <= distance <= 1:
        return 1/(distance**2)
    else:
        return 1

print(FetchTaxiStandScores(None))