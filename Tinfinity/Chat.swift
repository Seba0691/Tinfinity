import Foundation.NSDate
import JSQMessagesViewController
import Alamofire
import SwiftyJSON
import CoreData

var dateFormatter = NSDateFormatter()

class Chat {
    let user: User
    var lastMessageText: String
    var lastMessageSentDate: NSDate
    var lastMessageSentDateString: String {
    return formatDate(lastMessageSentDate)
    }
    var loadedMessages = [JSQMessage]()
    var allMessages = [JSQMessage]()
    var unreadMessageCount: Int = 0 // subtacted from total when read
    var hasUnloadedMessages = false
    var draft = ""
    
    let baseUrl = NSBundle.mainBundle().objectForInfoDictionaryKey("Server URL") as! String
    let chatListPath = NSBundle.mainBundle().objectForInfoDictionaryKey("Chat List Path") as! String


    init(user: User, lastMessageText: String, lastMessageSentDate: NSDate) {
        self.user = user
        self.lastMessageText = lastMessageText
        self.lastMessageSentDate = lastMessageSentDate
    }
    
    static func getChatByUserId(user_id: String) -> Chat? {
        for(var i=0; i < account.chats.count; i++){
            if (account.chats[i].user.userId == user_id){
                return account.chats[i]
            }
        }
        return nil
    }

    func formatDate(date: NSDate) -> String {
        let calendar = NSCalendar.currentCalendar()

        let last18hours = (-18*60*60 < date.timeIntervalSinceNow)
        let isToday = calendar.isDateInToday(date)
        let isLast7Days = (calendar.compareDate(NSDate(timeIntervalSinceNow: -7*24*60*60), toDate: date, toUnitGranularity: .CalendarUnitDay) == NSComparisonResult.OrderedAscending)

        if last18hours || isToday {
            dateFormatter.dateStyle = .NoStyle
            dateFormatter.timeStyle = .ShortStyle
        } else if isLast7Days {
            dateFormatter.dateFormat = "ccc"
        } else {
            dateFormatter.dateStyle = .ShortStyle
            dateFormatter.timeStyle = .NoStyle
        }
        return dateFormatter.stringFromDate(date)
    }
    
    func reorderChat(){
        /*Insertion Sort*/
        /*for i = 1:n,
        for (k = i; k > 0 and a[k] < a[k-1]; k--)
        swap a[k,k-1]*/
        
        for(var i = 1; i < self.allMessages.count; i++){
            
            for(var k = i; k > 0 && self.allMessages[k - 1].date.compare(self.allMessages[k].date) == NSComparisonResult.OrderedDescending; k--){
                
                let temp = allMessages[k-1]
            	allMessages[k-1] = allMessages[k]
                allMessages[k] = temp
            }
        }
        updateLastMessage()
        
    }
    /*
	*Inserts the chat in the right order, comparing it's date to the ones of already existing chats
	*/
    func insertChat(){
        var i = 0
        while(i < account.chats.count && self.lastMessageSentDate.compare(account.chats[i].lastMessageSentDate) == NSComparisonResult.OrderedAscending){
            i++
        }
        if(i == account.chats.count){
            account.chats.append(self)
        }else{
            account.chats.insert(self, atIndex: i+1)
        }

    }
    
    func updateLastMessage(){
        lastMessageSentDate = allMessages[allMessages.count-1].date
        lastMessageText = allMessages[allMessages.count-1].text
    }
    
    func fetchNewMessages(completion: (result: Bool) -> Void){
        
        let manager = Alamofire.Manager.sharedInstance
            
            //We need the timeinterval to speak with the server, but in milliseconds
            let timeinterval: Double = round(self.lastMessageSentDate.timeIntervalSince1970 * 1000)
        
        	let stringTime = NSString(format: "%.f",timeinterval) as! String
            
            
            manager.request(.GET, baseUrl + "/api/chat/" + self.user.userId + "/" + stringTime , encoding : .JSON)
                .responseJSON { (request, response, data, error) in
                    
                    if(error != nil) {
                        // If there is an error in the web request, print it to the console
                        println(error!.localizedDescription)
                    }else if(response != false){
                        var innerData = JSON(data!)
                        
                            let user1 = innerData["_id"]["user1"].string
                            let user2 = innerData["_id"]["user2"].string
                            
                            var newUser: User
                            let user1MessagesCount = innerData["user1"].count
                            let user2MessagesCount = innerData["user2"].count
                            let minute: NSTimeInterval = 60, hour = minute * 60, day = hour * 24
                            let date = NSDate(timeIntervalSinceNow: -minute)
                            
                            for(var k = 0 ; k < user1MessagesCount; k++){
                                
                                self.allMessages.append(self.createJSQMessage(user1!, localMessage: innerData["user1"][k]))
                                if (user1 != account.user.userId){
                                	self.unreadMessageCount++
                                }
                                
                            }
                            for (var k = 0; k < user2MessagesCount; k++){
                                
                                self.allMessages.append(self.createJSQMessage(user2!, localMessage: innerData["user2"][k]))
                                if (user2 != account.user.userId){
                                    self.unreadMessageCount++
                                }
                                
                            }
                            self.reorderChat()
                            completion(result: true)
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
    
    /*
	* Create a new record in the core data with the informations of the chat. Note that the function does not check if the record
    * already exists, since in the application flow it is called only when the application is launched for the first time or when a 
    * chat with a new user is created.
	*/
    func saveNewChat() {

        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let managedContext = appDelegate.managedObjectContext!
        
        let entityChat =  NSEntityDescription.entityForName("Chat",inManagedObjectContext:managedContext)
        let chat = NSManagedObject(entity: entityChat!,insertIntoManagedObjectContext:managedContext)
        
        let entityUser = NSEntityDescription.entityForName("User", inManagedObjectContext: managedContext)
        let user = NSManagedObject(entity: entityUser!, insertIntoManagedObjectContext: managedContext)
        
        // Setting entities properties
        
        // Chat
        chat.setValue(account.user.userId, forKey: "myUserId")
        chat.setValue(self.unreadMessageCount, forKey: "unreadMessagesCount")
        chat.setValue(self.lastMessageText, forKey: "lastMessageText")
        chat.setValue(self.lastMessageSentDate, forKey: "lastMessageDate")
        chat.setValue(self.hasUnloadedMessages, forKey: "hasUnloadedMessages")
        
        // User
        user.setValue(self.user.userId, forKey: "id")
        let stringURL = "\(self.user.imageUrl)"
        user.setValue(stringURL, forKey: "imageUrl")
        let imageData = UIImagePNGRepresentation(self.user.image)
        user.setValue(imageData, forKey: "image")
        user.setValue(self.user.firstName, forKey: "firstName")
        user.setValue(self.user.lastName, forKey: "lastName")
        user.setValue(self.user.email, forKey: "email")
        
        // Settiamo ora le relazioni tra le entità user e chat
        
        chat.setValue(user, forKey: "withUser")
        user.setValue(chat, forKey: "hasChat")
        
        //Bisogna salvare i messaggi
        var messagesManagedArray = [NSManagedObject]()
        for messageObject in self.allMessages {
            let entityMessage =  NSEntityDescription.entityForName("Message",inManagedObjectContext:managedContext)
            let message = NSManagedObject(entity: entityMessage!,insertIntoManagedObjectContext:managedContext)
            message.setValue(messageObject.text, forKey: "text")
            message.setValue(messageObject.date, forKey: "date")
            message.setValue(messageObject.senderId, forKey: "senderId")
            
            // Settiamo le relazioni tra i messaggi e la relativa chat
            message.setValue(chat, forKey: "belongsTo")
            messagesManagedArray.append(message)
        }
        
        let messagesSet = NSSet(array: messagesManagedArray)
        chat.setValue(messagesSet, forKey: "hasMessages")
        
        
        var error: NSError?
        if !managedContext.save(&error) {
            println("Could not save \(error), \(error?.userInfo)")
        }
    }
    
    func saveNewMessage(newMessage: JSQMessage, userId: String){
        
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let managedContext = appDelegate.managedObjectContext!
        let entityMessage =  NSEntityDescription.entityForName("Message",inManagedObjectContext:managedContext)
        let message = NSManagedObject(entity: entityMessage!,insertIntoManagedObjectContext:managedContext)
        
        message.setValue(newMessage.senderId, forKey: "senderId")
        message.setValue(newMessage.text, forKey: "text")
        message.setValue(newMessage.date, forKey: "date")
        
        //Let's look for the chat record
        let entity = "Chat"
        var request = NSFetchRequest(entityName: entity)
        var error: NSError?
        if let entities = managedContext.executeFetchRequest(
            request,
            error: &error
            ) as? [NSManagedObject] {
                for chat in entities {
                    let user = chat.valueForKey("withUser") as! NSManagedObject
                    if(chat.valueForKey("myUserId") as! String == account.user.userId && user.valueForKey("id") as! String == userId){
                        message.setValue(chat, forKey: "belongsTo")
                        
                        var messages = chat.valueForKey("hasMessages")!.allObjects as! [NSManagedObject]
                        messages.append(message)
                        let messagesSet = NSSet(array: messages)
                        chat.setValue(messagesSet, forKey: "hasMessages")
                    }
                }
            var error: NSError?
            if !managedContext.save(&error) {
                println("Could not save \(error), \(error?.userInfo)")
            }
        }
    }
    
    static func loadChatsFromCore(){
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        
        let managedContext = appDelegate.managedObjectContext!
        
        let fetchRequest = NSFetchRequest(entityName:"Chat")
        
    	var error: NSError?
        
        let fetchedResults = managedContext.executeFetchRequest(fetchRequest,error: &error) as? [NSManagedObject]
        
        if let results = fetchedResults {
            // For every chat we have found we need to load the relative user and the messages
            for chat in results{
                let user = chat.valueForKey("withUser") as! NSManagedObject
                let newUser = User(userId: user.valueForKey("id") as! String, firstName: user.valueForKey("firstName") as! String, lastName: user.valueForKey("lastName") as! String)
                let url = NSURL(fileURLWithPath: user.valueForKey("imageUrl") as! String)
                let image = user.valueForKey("image") as! NSData
                newUser.images[0] = UIImage(data: image)
                let date = chat.valueForKey("lastMessageDate") as! NSDate
                let newChat = Chat(user: newUser, lastMessageText: chat.valueForKey("lastMessageText") as! String, lastMessageSentDate: date)
                
                let messages = chat.valueForKey("hasMessages")!.allObjects as! [NSManagedObject]
                for message in messages{
                    let messageDate = message.valueForKey("date") as! NSDate
                    let newMessage = JSQMessage(senderId: message.valueForKey("senderId") as! String, senderDisplayName: newUser.name, date: messageDate, text: message.valueForKey("text") as! String)
                    newChat.allMessages.append(newMessage)
                }
                newChat.reorderChat()
                newChat.insertChat()
            }
        } else {
            println("Could not fetch \(error), \(error!.userInfo)")
        }
    }
    
  
}
