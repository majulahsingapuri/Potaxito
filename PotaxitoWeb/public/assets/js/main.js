var map;
var taxis = [];
var taxiLocations = [];
var heatmap;
var stands = {};

// ICONS
var iconBase = './assets/images/';
var icons = {
  stand: {
    icon: iconBase + 'Fryer%20Icon.png'
  },
  taxi: {
    icon: iconBase + 'Potato%20Icon.png'
  },
  chosenStand: {
    icon: iconBase + 'Fryer%20Full%20Icon.png'
  }
};

// Create the script tag, set the appropriate attributes
var script = document.createElement('script');
script.src = 'https://maps.googleapis.com/maps/api/js?key=APIKEY&libraries=visualization&callback=initMap';
script.async = true;

// Append the 'script' element to 'head'
document.head.appendChild(script);

// Attach your callback function to the `window` object
window.initMap = function () {
    map = new google.maps.Map(document.getElementById('map'), {
        center: {lat: 1.363895, lng: 103.816451},
        zoom: 11,
        mapTypeControlOptions: {
            mapTypeIds: [google.maps.MapTypeId.ROADMAP]
        },
        streetViewControl: false,
        fullscreenControl: false,
        maxZoom: 16,
        minZoom: 10,
        restriction: {
            latLngBounds: {
                north: 1.486419,
                south: 1.204253,
                east: 104.068515,
                west: 103.526064,
            }
        }
    });

    map.addListener('zoom_changed', () => {
        console.log('zoom changed')
        if (map.getZoom() > 13) {
        taxis.forEach(taxi => {
            taxi.setMap(map);
        });
        heatmap.setMap(null)
        } else {
        taxis.forEach(taxi => {
            taxi.setMap(null);
        });
        heatmap.setMap(map)
        }
    })
}

// FETCH STAND LOCATIONS
function fetchStandLocation() {
firebase.storage().refFromURL('gs://potatotaxis.appspot.com/standLocations.json').getDownloadURL()
    .then((url) => {
        $.getJSON(url, function (data) {
            for (const [key, value] of Object.entries(data)) {
                var stand = new google.maps.Marker({
                    position: {
                        lat: value['yCoord'],
                        lng: value['xCoord']
                    },
                    map: map,
                    icon: icons['stand'].icon
                });
                stands[key] = stand
            }
        });
    })
    .catch((error) => {
        var errorCode = error.code;
        var errorMessage = error.message;
        console.log(errorCode + ' ' + errorMessage)
    });
}

// FETCH TAXI LOCATIONS
function fetchTaxiLocation() {
    firebase.storage().refFromURL('gs://potatotaxis.appspot.com/TaxiLocations.json').getDownloadURL().then((url) => {
        $.getJSON(url, function (data) {
        taxis = [];
        taxiLocations = [];
        for (const [key, value] of Object.entries(data)) {
            var coord = new google.maps.LatLng(value['yCoord'], value['xCoord']);
            taxiLocations.push(coord);
            taxis.push(new google.maps.Marker({
                position: coord,
                map: null,
                icon: icons['taxi'].icon
            }))
        }
        heatmap = new google.maps.visualization.HeatmapLayer({
            data: taxiLocations,
            map: map
            });
        });
    });
}

// FIND OPTIMAL TAXI STAND
function findTaxiStand() {
    if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition( (position, err) => {

        if (err != null) {
            console.warn(err.message)
        }
        document.getElementById("FindTaxiStand").disabled = true;

        const yCoord  = position.coords.latitude;
        const xCoord = position.coords.longitude;

        var data = JSON.stringify({
            "xCoord" : xCoord,
            "yCoord" : yCoord
        })

        var xhr = new XMLHttpRequest()
        xhr.open("POST", "https://asia-southeast2-potatotaxis.cloudfunctions.net/FetchTaxiStandScores", true)
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function () {
            if (xhr.readyState === 4 && xhr.status === 200) {
                var taxiStandScore = JSON.parse(xhr.responseText);
                if (jQuery.isEmptyObject(taxiStandScore)) {
                    alert("No Taxi Stands found in your location")
                } else {
                    // deletes marker
                    stands[taxiStandScore['standID']].setMap(null)
                    stands[taxiStandScore['standID']] = new google.maps.Marker({
                        position: {
                            lat: taxiStandScore['data']['yCoord'],
                            lng: taxiStandScore['data']['xCoord']
                        },
                        map: map,
                        icon: icons['chosenStand'].icon
                    })
                    map.setZoom(16)
                    map.panTo({
                        lat: taxiStandScore['data']['yCoord'],
                        lng: taxiStandScore['data']['xCoord']
                    })
                }
                document.getElementById("FindTaxiStand").disabled = false;
            }
        };
        xhr.send(data);
    });
    } else {
        alert("Location is not supported by your browser.")
    }
}

// SHOW TAXI STANDS 
function showTaxiStands() {
    var toggle = document.getElementById("showTaxiStandSwitch");

    if (toggle.checked) {
        for (const [key, value] of Object.entries(stands)) {
            value.setMap(map)
        }
    } else {
        for (const [key, value] of Object.entries(stands)) {
            value.setMap(null)
        }
    }
}

// INITIALISE APP
window.onload = function() {
    document.addEventListener('DOMContentLoaded', function() {
    
    let app = firebase.app();
    
    });

    // LOGIN TO FIREBASE
    firebase.auth().signInAnonymously()
        .then(() => {
            console.log("signed in to firebase")
            fetchTaxiLocation()
            fetchStandLocation()
            setTimeout(() => {
                document.getElementById("FindTaxiStand").disabled = false;
            }, 3000);
        })
        .catch((error) => {
            var errorCode = error.code;
            var errorMessage = error.message;
            console.log(errorCode + ' ' + errorMessage)
        });
    // CLOUD MESSAGING
    firebase.messaging().requestPermission().then( function() {
        console.log("Permission granted")
        return messaging.getToken()
    }).then(function(token) {
        console.log(token)
    })
    .catch((error) => {
        var errorCode = error.code;
        var errorMessage = error.message;
        console.log(errorCode + ' ' + errorMessage)
    });

    firebase.messaging().onMessage(function (payload) {
        console.log(payload)
    })
}

// DELETE USER
window.addEventListener("beforeunload", function(event) { 
    event.preventDefault()
    console.log("closed") 
    deleteUser()
    event.returnValue = ' '
});
function deleteUser() {
    firebase.auth().currentUser.delete().then(function() {
        console.log("User deleted")
    })
    .catch((error) => {
        var errorCode = error.code;
        var errorMessage = error.message;
        console.log(errorCode + ' ' + errorMessage)
    });
}