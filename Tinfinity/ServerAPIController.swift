//
//  ServerAPIController.swift
//  Tinfinity
//
//  @author Alberto Fumagalli
//  @author Riccardo Mastellone
//

import Foundation
import Alamofire
import SwiftyJSON
import JSQMessagesViewController

class ServerAPIController{
    
    var FBToken : String
    let authenticationPath: String
    let baseUrl: String
    let chatListPath: String
    
    init(FBAccessToken: String){
        FBToken = FBAccessToken
        baseUrl = NSBundle.mainBundle().objectForInfoDictionaryKey("Server URL") as! String
        authenticationPath = NSBundle.mainBundle().objectForInfoDictionaryKey("Authentication Path") as! String
        chatListPath = NSBundle.mainBundle().objectForInfoDictionaryKey("Chat List Path") as! String
        // Retreive the managedObjectContext from AppDelegate
        let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
    }
    
    //Funzione che chiama il server e setta i parametri dell'utente. Ritorna true se la richiesta è andata a buon fine,altrimenti false
    func retrieveProfileFromServer(completion: (result: Bool) -> Void){
            
            Alamofire.request(.POST, baseUrl + authenticationPath, parameters: ["token" : FBToken], encoding : .JSON)
                .responseJSON { (request, response, data, error) in
                    
                    if(error != nil) {
                        // If there is an error in the web request, print it to the console
                        println(error!.localizedDescription)
                
                        completion(result: false)
                    }else{
                    
                    var json = JSON(data!)
                    
                    let id = json["_id"].string
                    let name = json["name"].string
                    let surname = json["surname"].string
                    account.token = json["token"].string
                    
                    
                    //Settiamo per tutta la sessione il manger alamofire affinche abbia il token nell'header per l'autenticazione in tutte le chiamate al server
                    let manager = Alamofire.Manager.sharedInstance
                    manager.session.configuration.HTTPAdditionalHeaders = ["X-Api-Token": account.token!]
                        
                    account.user = User(userId: id!, firstName: name!, lastName: surname!)
                    account.user.email = json["email"].string
                    account.user.imageUrl = NSURL(string: json["image"].string!)
                    account.user.fetchImage()
                        
                    println("User Token: " + account.token)
                    completion(result: true)
            		}
       			 }
    }
    
    func retriveChatHistory(id: String, completion: (result: [(Chat)] ) -> Void){
        
        let manager = Alamofire.Manager.sharedInstance
        
        manager.request(.GET, baseUrl + "/api/chat", encoding : .JSON)
            .responseJSON { (request, response, data, error) in
                
                if(error != nil) {
                    // If there is an error in the web request, print it to the console
                    println(error!.localizedDescription)
                }else{
                    
                    var json = JSON(data!)
                    let length = json.count
                    
                    for(var i = 0; i < length; i++ ){
                        
                        let innerData = json[i]
                        let user1 = innerData["_id"]["user1"].string
                        let user2 = innerData["_id"]["user2"].string
                        
                        var newUser: User
                        let user1MessagesCount = innerData["user1"].count
                        let user2MessagesCount = innerData["user2"].count
                        
                        //This date is only needed to initialize the chat. It will be updated after
                        let date = NSDate()
                        
                        if (user1 == account.user.userId){
                            //Creiamo un nuovo oggetto user che ha come utente l'id di user2, poichè entrati in questo if user1 coincide con l'id utente dell'accunt in uso. Altrimenti inizializziamo l'user con id user1
                            newUser = User(userId: user2!,firstName: "",lastName: "")
                        }else{
                            newUser = User(userId: user1!,firstName: "",lastName: "")
                        }
                        // Retrieve user data
                        newUser.fetch({ (result) -> Void in
                        
                            var newChat = Chat(user: newUser,lastMessageText: "",lastMessageSentDate: date)
                            
                            for(var k = 0 ; k < user1MessagesCount; k++){
                                
                                newChat.allMessages.append(self.createJSQMessage(user1!, localMessage: innerData["user1"][k]))
                                
                            }
                            for (var k = 0; k < user2MessagesCount; k++){
                                
                                newChat.allMessages.append(self.createJSQMessage(user2!, localMessage: innerData["user2"][k]))
                                
                            }
                            newChat.reorderChat()
                            newChat.saveNewChat()
                            newChat.insertChat()
                            completion(result: account.chats)
                        })
                       
                    }
                    
                }
                
        }
    }
    
    func createJSQMessage(user: String,localMessage: JSON)->JSQMessage{
        
        let newMessage = localMessage["message"].string
        let timestamp = localMessage["timestamp"].double!/1000
        let text = localMessage["message"].string
        let myDouble = NSNumber(double: timestamp)
        let date = NSDate(timeIntervalSince1970: Double(myDouble))
        let message = JSQMessage(senderId: user,senderDisplayName: "Sender",date: date,text: text)
        return message
        
    }

    
    
}