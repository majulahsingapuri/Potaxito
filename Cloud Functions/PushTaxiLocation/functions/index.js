const functions = require('firebase-functions');

// The Firebase Admin SDK to access Firestore.
const admin = require('firebase-admin');
admin.initializeApp();

const path = require('path');

// send notification to all devices that new info is available
exports.PushTaxiLocations = functions.region('asia-southeast2').storage.bucket('potatotaxis.appspot.com').object().onFinalize( (object) => {
    // [START eventAttributes]
    const filePath = object.name; // File path in the bucket.
    // [END eventAttributes]

    //[START stopConditions]
    // Get the file name.
    const fileName = path.basename(filePath);
    if (fileName != 'TaxiLocations.json') {
        return console.log('Updated file ' + fileName + '.');
    }
    // [END stopConditions]

    var message = {
        data: {
            message: 'updated taxi locations!'
        },
        topic: 'TaxiLocationsUpdated'
    };

    // Send a message to devices subscribed to the provided topic.
    admin.messaging().send(message)
    .then((response) => {
        // Response is a message ID string.
        console.log('Successfully sent message:', response);
    })
    .catch((error) => {
        console.log('Error sending message:', error);
    });
});
