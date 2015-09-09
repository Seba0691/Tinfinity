//
//  ViewController.swift
//  Tinfinity
//
//  @author Alberto Fumagalli
//  @author Riccardo Mastellone
//  @author Sebastiano Mariani
//

import UIKit
import Alamofire
import Socket_IO_Client_Swift
import MapKit
import CoreLocation
import Foundation

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    var profile: User?
    var timer: NSTimer?
    
    //Metodi per la posizione sulla mappa
    
    @IBOutlet weak var titleItem: UIBarButtonItem!
    @IBOutlet var mapView: MKMapView!
    @IBOutlet weak var chatButton: UIBarButtonItem!
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    
    let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor(red: 247/255, green: 246/255, blue: 243/255, alpha: 1)
        
        // Require Location Permissions
        locationManager.requestWhenInUseAuthorization()
        
        // Check if permissions are given
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            
            // Set the timer every 2 minutes
            timer =  NSTimer.scheduledTimerWithTimeInterval(20, target: self, selector: Selector("refreshLocation"), userInfo: nil, repeats: true)
            
            // Get first location
            refreshLocation()
            
        } else {
            //@TODO Block App
        }
        
        // We don't want our user to mess with the map
        self.mapView.zoomEnabled = false;
        self.mapView.scrollEnabled = false;
        
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        
        // Lets first update our Model
        let location = locations.last as? CLLocation
        account.setLocation(CLLocationCoordinate2D(latitude: location!.coordinate.latitude, longitude: location!.coordinate.longitude ))
        
        if let location = account.user.position {
            let region = MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
            self.mapView.setRegion(region, animated: true)
        
            // Until we add our nicely designer marker, lets use Apple one
            self.mapView.showsUserLocation = true
            
            // Stop tracking until next call
            locationManager.stopUpdatingLocation()
            self.plotUsersToMap()
        }
    }
    
    func plotUsersToMap(){
        for(var i = 0; i < account.users.count; i++){
            let dropPin = UserAnnotation(user: account.users[i])
            mapView.addAnnotation(dropPin)
        }
    }
    
    /*
     * We don't need to keep refreshing the location all the time, hence we 
     * use 2 minute timer.
     */
    func refreshLocation(){
        println("Refreshing Location...");
        locationManager.startUpdatingLocation()
    }
    
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        let alertController = UIAlertController(title: "TinFinity", message:
            "Error while updating location!", preferredStyle: UIAlertControllerStyle.Alert)
        alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default,handler: nil))
        println("Error while updating location " + error.localizedDescription)
    }
    
   func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
    
    	if (annotation is MKUserLocation) {
        	return nil
    	}
        
    	let reuseId = "Annotation"
    	if annotation is UserAnnotation{
            
    		var annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId)
			if annotationView == nil{
                //If annotationView is nil a new one is created
            	annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            	annotationView.canShowCallout = true
                
                var calloutButton = UIButton.buttonWithType(.DetailDisclosure) as! UIButton
                
                annotationView!.rightCalloutAccessoryView = calloutButton
            
    		}
        	else{
                //Else we use this annotationView to show the new annotation
        		annotationView.annotation = annotation
    		}
            
        let customAnnotation = annotation as! UserAnnotation
        annotationView.image = ImageUtil.cropToSquare(image: customAnnotation.image)
            
    	return annotationView
    }
    
    	return nil
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, calloutAccessoryControlTapped control: UIControl!) {
        println("bottone cliccato")
        if let annotation = view.annotation as? UserAnnotation {
            performSegueWithIdentifier("newChat", sender: view)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        refreshLocation()
    }
    
    @IBAction func unwindToHome(segue: UIStoryboardSegue) {
        
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "newChat") {
            if let senderObject = sender as? MKAnnotationView{
                let navViewController = segue.destinationViewController as! UINavigationController
                let chatListController = navViewController.topViewController as! ChatListViewController
                let userAnn = sender!.annotation as! UserAnnotation
                if let senderAnnotation = senderObject.annotation as? UserAnnotation{
                    if let chat = Chat.getChatByUserId(senderAnnotation.user.userId){
                        chatListController.newChat = false
                        chatListController.clickedUserId = senderAnnotation.user.userId
                    }else{
                		chatListController.newChat = true
                		account.chats.insert(Chat(user: senderAnnotation.user, lastMessageText: "", lastMessageSentDate: NSDate()), atIndex: 0)
                        account.chats[0].saveNewChat()
                    }
            	}
        	}
    	}
    }
    
}
