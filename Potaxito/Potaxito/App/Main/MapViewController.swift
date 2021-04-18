//
//  MapViewController.swift
//  HeatmapTrial
//
//  Created by Bhargav Singapuri on 1/2/21.
//

import UIKit
import Network
import Firebase
import FirebaseAuth
import GoogleMaps
import GoogleMapsUtils
import JGProgressHUD

class MapViewController: UIViewController {
    
    var locationManager : CLLocationManager!
    var userLocation: CLLocation?
    var preciseLocationZoomLevel: Float = 15.0
    var approximateLocationZoomLevel: Float = 10.0
    var uid : String?
    var taxiMarkers : [TaxiMarker] = []
    var taxiStandMarkers : [Int : TaxiStandMarker] = [:]
    var chosenTaxiStand : TaxiStandMarker?
    var heatmap : GMUHeatmapTileLayer!
    var markerLocation : CLLocationCoordinate2D! {
        didSet {
            userLocationMarker.position = markerLocation
        }
    }
    var userLocationMarker : GMSMarker = GMSMarker()
    var pathStatus : NWPath.Status = .unsatisfied
    var locationStatus : CLAuthorizationStatus = .denied
    var locationAccuracy : CLAccuracyAuthorization?
    
    let monitor = NWPathMonitor()
    let queue = DispatchQueue(label: "InternetConnectionMonitor")
    let hud: JGProgressHUD = {
        let hud = JGProgressHUD(style: .dark)
        hud.interactionType = .blockAllTouches
        return hud
    }()
    
    @IBOutlet weak var MapView: GMSMapView!
    @IBOutlet weak var findTaxiStandButton: UIButton!
    @IBOutlet weak var taxiStandToggle: UISwitch!
    @IBOutlet weak var refreshButton: UIButton!
    @IBOutlet weak var infoButton: UIButton!
    @IBOutlet weak var closeInfoButton: UIButton!
    @IBOutlet weak var infoView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupGoogleMaps()
        firebaseLogin()
        fetchTaxiLocations()
        fetchTaxiStands()
        setupTimer()
        setupUI()
    }
    
    func setupGoogleMaps() {
        locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.distanceFilter = 50
        locationManager.startUpdatingLocation()
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.delegate = self
        locationManager.requestLocation()
        MapView.setMinZoom(10, maxZoom: 16)
        MapView.isMyLocationEnabled = true
        MapView.cameraTargetBounds = GMSCoordinateBounds(coordinate: CLLocationCoordinate2D(latitude: 1.486419, longitude: 104.068515), coordinate: CLLocationCoordinate2D(latitude: 1.204253, longitude: 103.526064))
        MapView.settings.rotateGestures = false
        MapView.settings.tiltGestures = false
        MapView.settings.indoorPicker = false
        MapView.delegate = self
        heatmap = GMUHeatmapTileLayer()
        heatmap.map = MapView
        userLocationMarker.map = MapView
        markerLocation = CLLocationCoordinate2D(latitude: 1.354599, longitude: 103.816756)
        let camera = GMSCameraPosition.camera(withLatitude: markerLocation.latitude, longitude: markerLocation.longitude, zoom: 10.0)
        MapView.camera = camera
    }
    
    func firebaseLogin() {
        Auth.auth().signInAnonymously { [weak self] (authResult, err) in
            if let err = err { // unwrapping optional
                print(err.localizedDescription) // put as pop-up
                return
            }
            guard let user = authResult?.user else { return }
            self?.uid = user.uid
        }
    }
    
    @objc func fetchTaxiLocations() {
        hud.indicatorView = JGProgressHUDIndeterminateIndicatorView()
        hud.textLabel.text = "Fetching Taxis"
        hud.show(in: view, animated: true)
        FetchTaxiLocations().fetch(map: MapView) { [weak self] (fetchedTaxiMarkers) in
            if let fetchedTaxiMarkers = fetchedTaxiMarkers {
                var list : [GMUWeightedLatLng] = []
                for taxi in fetchedTaxiMarkers {
                    let coords = GMUWeightedLatLng(coordinate: taxi.position, intensity: 1.0)
                    list.append(coords)
                    if let zoom = self?.MapView.camera.zoom, zoom <= 13 {
                        taxi.map = nil
                    } else {
                        taxi.map = self?.MapView
                    }
                }
                if let self = self {
                    for taxi in self.taxiMarkers {
                        taxi.map = nil
                    }
                }
                self?.heatmap.weightedData = list
                self?.heatmap.map = self?.MapView
                self?.taxiMarkers = fetchedTaxiMarkers
                self?.hud.indicatorView = JGProgressHUDSuccessIndicatorView()
                self?.hud.dismiss(afterDelay: 0.5, animated: true)
            } else {
                self?.hud.indicatorView = JGProgressHUDErrorIndicatorView()
                self?.hud.textLabel.text = "Unable to fetch Taxis"
                self?.hud.dismiss(afterDelay: 1.0, animated: true)
            }
        }
    }
    
    func fetchTaxiStands() {
        FetchTaxiStands().fetch(map: MapView) { [weak self] (taxiStandMarkers) in
            if let taxiStandMarkers = taxiStandMarkers {
                for stand in taxiStandMarkers {
                    self?.taxiStandMarkers[stand.id] = stand
                }
            } else {
                print("No taxi stands found")
            }
        }
    }
    
    func setupTimer() {
        let startDate = Date()
        let calendar = Calendar.current
        let minutes = calendar.component(.minute, from: startDate)
        let result = 6 - (minutes % 5)
        let date = calendar.date(byAdding: .minute, value: result, to: startDate)
        
        if let date = date {
            _ = Timer(fireAt: date, interval: 300, target: self, selector: #selector(fetchTaxiLocations), userInfo: nil, repeats: true)
        } else {
            _ = Timer(timeInterval: 300, target: self, selector: #selector(fetchTaxiLocations), userInfo: nil, repeats: true)
        }
    }
    
    func setupUI() {
        findTaxiStandButton.layer.cornerRadius = 6
        findTaxiStandButton.tintColor = .systemBlue
        taxiStandToggle.onTintColor = .systemBlue
        infoView.isHidden = true
        infoView.layer.cornerRadius = 15
        monitor.pathUpdateHandler = { [weak self] pathUpdateHandler in
            if pathUpdateHandler.status == .satisfied {
                DispatchQueue.main.async {
                    self?.pathStatus = .satisfied
                    self?.enableButtons()
                }
            } else {
                DispatchQueue.main.async {
                    self?.pathStatus = .unsatisfied
                    let alertvc = UIAlertController(title: "No internet connection", message: "Please connect to a network", preferredStyle: .alert)
                    alertvc.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                    self?.present(alertvc, animated: true, completion: nil)
                    self?.enableButtons()
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func setTaxiMap(map: GMSMapView?) {
        for taxi in taxiMarkers {
            taxi.map = map
        }
    }
    
    func findTaxiStand(location: CLLocationCoordinate2D) {
        self.hud.indicatorView = JGProgressHUDIndeterminateIndicatorView()
        self.hud.textLabel.text = "Finding optimal Taxi Stand"
        self.hud.show(in: view, animated: true)
        FetchChosenStand().fetch(map: self.MapView, location: location) { [weak self] (taxiStand, err) in
            if let err = err {
                DispatchQueue.main.async {
                    self?.hud.indicatorView = JGProgressHUDErrorIndicatorView()
                    self?.hud.textLabel.text = err.localizedDescription
                    self?.hud.dismiss(afterDelay: 1.0, animated: true)
                }
                return
            }
            if let taxiStand = taxiStand, let self = self, let marker = self.taxiStandMarkers[taxiStand.id], taxiStand.changeState(state: .chosen) {
                if let chosenTaxiStand = self.chosenTaxiStand {
                    let _ = chosenTaxiStand.changeState(state: .normal)
                }
                self.MapView.animate(to: GMSCameraPosition(latitude: marker.position.latitude, longitude: marker.position.longitude, zoom: 16))
                marker.map = nil
                self.taxiStandMarkers[taxiStand.id] = taxiStand
                self.chosenTaxiStand = taxiStand
                DispatchQueue.main.async {
                    self.hud.indicatorView = JGProgressHUDSuccessIndicatorView()
                    self.hud.dismiss(afterDelay: 0.5, animated: true)
                }
            } else {
                DispatchQueue.main.async {
                    self?.hud.indicatorView = JGProgressHUDErrorIndicatorView()
                    self?.hud.textLabel.text = "Error"
                    self?.hud.dismiss(afterDelay: 1.0, animated: true)
                }
                return
            }
        }
    }
    
    func enableButtons() {
        var enable = false
        if let accuracy = locationAccuracy, (accuracy == .fullAccuracy && (locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse) && pathStatus == .satisfied) {
            enable = true
        }
        refreshButton.isEnabled = enable
        findTaxiStandButton.isEnabled = enable
    }
    
    @IBAction func findTaxiStandPressed(_ sender: Any) {
        if userLocation != nil {
            let alertvc = UIAlertController(title: "Location Preference", message: "Would you like to use your current location or the marker location?", preferredStyle: .alert)
            let currentAlertAction = UIAlertAction(title: "Current Location", style: .default) { [weak self] (_) in
                guard let location = self?.locationManager.location?.coordinate else {return}
                self?.findTaxiStand(location: location)
            }
            let markerAlertAction = UIAlertAction(title: "Marker Location", style: .default) { [weak self] (_) in
                guard let location = self?.markerLocation else {return}
                self?.findTaxiStand(location: location)
            }
            let cancelAlertAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertvc.addAction(currentAlertAction)
            alertvc.addAction(markerAlertAction)
            alertvc.addAction(cancelAlertAction)
            self.present(alertvc, animated: true, completion: nil)
        } else {
            guard let location = markerLocation else {return}
            findTaxiStand(location: location)
        }
    }
    
    @IBAction func taxiStandTogglePressed(_ sender: UISwitch) {
        var map : GMSMapView? = nil
        if sender.isOn {
            map = MapView
        }
        for stand in taxiStandMarkers.values {
            stand.map = map
        }
    }
    
    @IBAction func refreshButtonTapped(_ sender: UIButton) {
        fetchTaxiLocations()
    }
    
    @IBAction func infoButtonPressed(_ sender: UIButton) {
        infoView.isHidden = false
    }
    
    @IBAction func closeInfoButtonPressed(_ sender: UIButton) {
        infoView.isHidden = true
    }
}

extension MapViewController : CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let currentLocation = locations.last {
            userLocation = currentLocation
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let alertVC = UIAlertController(title: "Error", message: "Unable to get location", preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
        self.present(alertVC, animated: true) {
            manager.requestLocation()
            if let location = self.markerLocation {
                let camera = GMSCameraPosition.camera(withLatitude: location.latitude, longitude: location.longitude, zoom: 10.0)
                self.MapView.camera = camera
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let accuracy = manager.accuracyAuthorization
        locationStatus = status
        locationAccuracy = accuracy
        enableButtons()
        if (status == .authorizedAlways || status == .authorizedWhenInUse) && accuracy == .fullAccuracy, let location = locationManager.location {
            userLocation = location
            markerLocation = location.coordinate
            let camera = GMSCameraPosition.camera(withLatitude: markerLocation.latitude, longitude: markerLocation.longitude, zoom: 10.0)
            MapView.camera = camera
        } else {
            let alertvc = UIAlertController (title: "Enable Location", message: "Enable precise location to access all features.", preferredStyle: .alert)
            let settingsAction = UIAlertAction(title: "Settings", style: .default) { (_) -> Void in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {return}
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, completionHandler: nil)
                }
            }
            alertvc.addAction(settingsAction)
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertvc.addAction(cancelAction)
            present(alertvc, animated: true, completion: nil)
        }
    }
}

extension MapViewController : GMSMapViewDelegate {
    
    func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
        if position.zoom <= 13 {
            setTaxiMap(map: nil)
            heatmap.map = MapView
        } else {
            setTaxiMap(map: MapView)
            heatmap.map = nil
        }
    }
    
    func mapView(_ mapView: GMSMapView, didLongPressAt coordinate: CLLocationCoordinate2D) {
        markerLocation = coordinate
    }
}
