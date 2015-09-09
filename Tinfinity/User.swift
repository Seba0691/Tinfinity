//
//  UserProfile.swift
//  Tinfinity
//
//  @author Alberto Fumagalli
//  @author Riccardo Mastellone
//
import Foundation.NSString
import UIKit
import Alamofire
import SwiftyJSON

// Maximum number of photos a user can have
let MAX_PHOTOS = 6

class User {
    
    enum Gender {
        case Male
        case Female
    }
    
    var userId: String
    var firstName: String
    var lastName: String
    var gender: Gender?
    var email: String?
    
    // Main image
    var image: UIImage? {
        return images[0]
    }
    
    // Main image URL
    var imageUrl : NSURL?
    
    // Images array
    var images = [UIImage?](count: MAX_PHOTOS, repeatedValue:nil)
    
    // User position
    var position: CLLocationCoordinate2D?
    
    
    /* Utilities */
    
    // Fullname
    var name: String? {
        return firstName + " " + lastName
    }
    
    // User initials
    var initials: String? {
        var initials: String?
        for name in [firstName, lastName] {
            var initial = name.substringToIndex(advance(name.startIndex, 1))
            if initial.lengthOfBytesUsingEncoding(NSNEXTSTEPStringEncoding) > 0 {
                initials = (initials == nil ? initial : initials! + initial)
            }
        }
        return initials
    }
    
    init(userId: String, firstName: String, lastName: String) {
        self.userId = userId
        self.firstName = firstName
        self.lastName = lastName
    }
    
    static func getUserById(user_id: String) -> User? {
        for(var i=0; i < account.users.count; i++){
            if (account.users[i].userId == user_id){
                return account.users[i]
            }
        }
        return nil
    }
    
    /**
     * Recuperiamo dal server le informazioni legate all'utente
     */
    func fetch(completion: (result: User? ) -> Void) {
        let manager = Alamofire.Manager.sharedInstance
        
        manager.request(.GET, NSBundle.mainBundle().objectForInfoDictionaryKey("Server URL") as! String + "/api/users/" + userId, encoding : .JSON)
            .responseJSON { (request, response, data, error) in
                
                if(error != nil) {
                    // If there is an error in the web request, print it to the console
                    println(error!.localizedDescription)
                } else {
                    var json = JSON(data!)
                    if let errore = json["error"].string{
                        
                        for(var i=0; i < account.chats.count; i++){
                            if (account.chats[i].user.userId == self.userId){
                                account.chats.removeAtIndex(i)
                                println("An user has been removed from the array")
                                completion(result: nil)
                            }
                        }
                        
                    }else{
                    	self.firstName = json["name"].string!
                    	self.lastName = json["surname"].string!
                    	self.imageUrl = NSURL(string: json["image"].string!)
                    	if(json["gender"] == "male") {
                        	self.gender = Gender.Male
                    	} else {
                    	    self.gender = Gender.Female
                   	 	}
                    
                    	// Lets download the image
                    	self.fetchImage()
                        completion(result: self)
                    }
                }
        }
    }
    
    /**
     * Downloads the remote image into a UIImage with
     * a default image fallback
     */
    func fetchImage() {
        if let url = self.imageUrl {
            let data = NSData(contentsOfURL: url)
            if (data != nil){
            	return self.images[0] = UIImage(data: data!)!
        	}
    	}
        return self.images[0] = UIImage(named: "Blank")
    }
    

}

