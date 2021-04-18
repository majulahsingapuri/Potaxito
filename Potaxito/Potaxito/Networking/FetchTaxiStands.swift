//
//  FetchTaxiStands.swift
//  Potaxito
//
//  Created by Nicolette Hay on 25/2/21.
//

import SwiftyJSON
import GoogleMaps
import FirebaseStorage

struct FetchTaxiStands {
    
    func fetch(map: GMSMapView, completion: @escaping ([TaxiStandMarker]?) -> ()) {
        
        let ref = Storage.storage().reference().child("standLocations.json")
        
        ref.getData(maxSize: 5 * 1024 * 1024) { (data, err) in
            if let err = err {
                print(err.localizedDescription)
                completion(nil)
            }
            var taxiStandMarkers : [TaxiStandMarker] = []
            do {
                if let data = data {
                    let stands = try JSON(data: data)
                    for (standID, location):(String, JSON) in stands {
                        if let standID = Int(standID), let xCoord = location["xCoord"].float, let yCoord = location["yCoord"].float {
                            let stand = TaxiStandMarker(xCoord: xCoord, yCoord: yCoord, myMap: map, id: standID)
                            taxiStandMarkers.append(stand)
                        }
                    }
                    completion(taxiStandMarkers)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }
    }
}

