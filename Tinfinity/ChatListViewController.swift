//
//  ChatListViewController.swift
//  Tinfinity
//
//  @author Alberto Fumagalli
//  @author Riccardo Mastellone
//  @author Sebastiano Mariani
//

import UIKit
import SocketIOClientSwift
import SwiftyJSON
import JSQMessagesViewController

class ChatListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var homeButton: UIButton!
    @IBOutlet weak var chatTableView: UITableView!
    @IBOutlet weak var defaultMessage: UILabel!
    @IBOutlet weak var viewSwitch: UISegmentedControl!
    @IBOutlet weak var requestView: UIView!
    
    
    //Weak reference to parent pageViewController
    weak var pageViewController: PageViewController?
    
    var sendRequestUserIndexPath: NSIndexPath? = nil
    
    var chats: [Chat] { return account.chats }
    var imageCache = [String:UIImage]()
    
    
    /* newChat can assume 3 values:
	 * - nil: means the user got in this controller by simply clicking the regoular button
	 * - false: means the user got in this controller by selecting a nearby user on the map, so we have to open the
	 *			relative chat, which already exists
	 * - true: means the user got here by selecting a nearby user with whom he never chatted before.
     *
     *  The check on this is made in the preparefore segue with id: chatSelected
	 */
    var newChat: Bool?
    
    // The id passed by the map that tells us which is the chat we need to open
    var clickedUserId: String?
    
    var refreshControl: UIRefreshControl!
    
    // Socket IO client
    private let socket = SocketIOClient(socketURL: NSURL(string:NSBundle.mainBundle().objectForInfoDictionaryKey("Server URL") as! String)!)
    
    var isConnected = false
    
    /*
    ##################   START-UP AND APPEAR/DISAPPEAR BEHAVIOUR   ##################
	*/
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //If we come from vewiController(The map controller) it mean we have to directly create a detailVIewController
        if(newChat != nil){
            performSegueWithIdentifier("chatSelected", sender: self)
        }
        
        self.connectToServer()
        self.addHandler()
        
        //The defualt message is hidden by default
        defaultMessage.hidden = true
        defaultMessage.text = "You have no people connected to you. Look in the map to start chatting!"
        
        // Do any additional setup after loading the view.
        self.view.backgroundColor = UIColor(red: 247/255, green: 246/255, blue: 243/255, alpha: 1)
        
        //If we have no messages in the list we hide the tableView and show the defaultMessage
        if(chats.count == 0){
            chatTableView.hidden = true
            defaultMessage.hidden = false
        }
        
        //Implement the pull to refresh
		self.refreshControl = UIRefreshControl()
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.refreshControl.addTarget(self, action: Selector("updateData"), forControlEvents: UIControlEvents.ValueChanged)
        self.chatTableView.addSubview(refreshControl)
        
        // Hide the activity indicator
        self.stopLoading()
        
        // Select default tab in segmented control and
        // hide the requests view
        self.viewSwitch.selectedSegmentIndex = 0
        self.requestView.hidden = true
        
        // Sort the rows
        account.reorderChat()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.newChat = nil
    }
    override func viewWillAppear(animated: Bool) {
        self.navigationController?.navigationBarHidden = true
        if(newChat == nil || newChat == false){
            for(var i = 0; i < chats.count; i++){
                chats[i].updateLastMessage()
            }
            chatTableView.reloadData()
        }
    }
    
    func loading() {
        self.activityIndicator.startAnimating()
    }
    
    func stopLoading() {
        self.activityIndicator.stopAnimating()
    }
    
    
    /**
     * Switch between tab views
     */
    @IBAction func viewSwitch(sender: UISegmentedControl) {
    	switch viewSwitch.selectedSegmentIndex {
        case 0: // Conversations Tab
            requestView.hidden = true
            chatTableView.hidden = false
        case 1: // Requests Tab
            requestView.hidden = false
            chatTableView.hidden = true
        default:
            break;
        }
    }
    /*
    ##################   TABLE-VIEW SETUP   ##################
    */

    
   func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chats.count
        
    }
    
   func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    //Life cycle
   func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        //we need to obtain the cell to set his values
        let cell = chatTableView.dequeueReusableCellWithIdentifier("chatCell") as! ChatCustomCell
        let chat = chats[indexPath.row]
    
        // Update the cell with the avatars
        dispatch_async(dispatch_get_main_queue(), {
            if let cellToUpdate = tableView.cellForRowAtIndexPath(indexPath) as? ChatCustomCell {
                cellToUpdate.chatAvatar.image = ImageUtil.cropToSquare(image: chat.user.image!)
            }
        })
    
    	//Now we need to make the chatAvatar look round
    	let frame = cell.chatAvatar.frame
    	let imageSize = frame.size.height
    	cell.chatAvatar.frame = frame
    	cell.chatAvatar.layer.cornerRadius = imageSize / 2.0
    	cell.chatAvatar.clipsToBounds = true
    
        cell.nameLabel.text = chat.user.name
        cell.messageLabel.text = chat.lastMessageText
    	cell.messageTime.text = chat.lastMessageSentDateString
    	cell.unreadMessagesNumber.layer.cornerRadius = 9
    	if(chat.unreadMessageCount != 0){
        	cell.unreadMessagesNumber.hidden = false
            cell.unreadMessagesNumber.setTitle(String(chat.unreadMessageCount), forState: .Normal)
            cell.messageTime.textColor = UIColor.blueColor()
        }else{
        	cell.unreadMessagesNumber.hidden = true
            cell.messageTime.textColor = UIColor.blackColor()
    	}
        
        return cell
    }
    
    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .Normal, title: "Delete") { action, index in
            account.chats[indexPath.row].deleteChat()
            account.chats.removeAtIndex(indexPath.row)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
        delete.backgroundColor = UIColor(red: 231/255.0, green: 76/255.0, blue:60/255.0, alpha: 1)
        
        // Non sono amici ed è stata ricevuta una richiesta
        if(account.chats[indexPath.row].user.hasReceivedRequest == true) {
            let accept = UITableViewRowAction(style: .Normal, title: "Accept") { action, index in
                self.loading()
                account.chats[indexPath.row].user.acceptFriendRequest({ (_) in
                    self.stopLoading()
                })
                tableView.setEditing(false, animated: true)
            }
            accept.backgroundColor = UIColor(red: 46/255.0, green: 206/255.0, blue:113/255.0, alpha: 1)
            let decline = UITableViewRowAction(style: .Normal, title: "Decline") { action, index in
                self.loading()
                account.chats[indexPath.row].user.declineFriendRequest({ (_) in
                    self.stopLoading()
                })
                tableView.setEditing(false, animated: true)
            }
            decline.backgroundColor = UIColor(red: 52/255.0, green: 73/255.0, blue:94/255.0, alpha: 1)
            return [delete, decline, accept]
        }
        // Non sono amici ed e non è stata inviata una richiesta
        else if (account.chats[indexPath.row].user.isFriend == false &&
            account.chats[indexPath.row].user.hasSentRequest == false) {
                let request = UITableViewRowAction(style: .Normal, title: "Send\nrequest") { action, index in
                    
                    self.sendRequestUserIndexPath = indexPath
                    self.confirmRequest(account.chats[indexPath.row].user.name!)
                    tableView.setEditing(false, animated: true)
                }
                request.backgroundColor = UIColor(red: 52/255.0, green: 152/255.0, blue:219/255.0, alpha: 1)
                return [delete, request]
        }
        // Sono amici 
        else if (account.chats[indexPath.row].user.isFriend == true) {
                let unfriend = UITableViewRowAction(style: .Normal, title: "Unfriend") { action, index in
                    self.loading()
                    account.chats[indexPath.row].user.declineFriendRequest({ (_) in
                        self.stopLoading()
                    })
                    tableView.setEditing(false, animated: true)
                }
                unfriend.backgroundColor = UIColor(red: 52/255.0, green: 152/255.0, blue:219/255.0, alpha: 1)
                return [delete, unfriend]
        }
        
        return [delete]
    }
    
    func confirmRequest(username: String) {
        let alert = UIAlertController(title: "Send Friend Request", message: "Do you want to add \(username)?", preferredStyle: .ActionSheet)
        
        let confirmAction = UIAlertAction(title: "Send", style: .Default, handler: handleSendRequest)
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: cancelSendRequest)
        
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func handleSendRequest(alertAction: UIAlertAction!) -> Void {
        if let indexPath = sendRequestUserIndexPath {
            loading()
            sendRequestUserIndexPath = nil
            account.chats[indexPath.row].user.sendFriendRequest({ (_) in
                self.stopLoading()
            })
        }
    }
    
    func cancelSendRequest(alertAction: UIAlertAction!) {
        sendRequestUserIndexPath = nil
    }
        
    
    /*
    ##################   BUTTONS AND SEGUE PREPARATION   ##################
    */
    
    @IBAction func homeButtonClicked(sender: AnyObject){
        let newViewController = self.pageViewController!.viewControllerAtIndex(1)
        self.pageViewController!.setViewControllers([newViewController], direction: .Reverse, animated: true,completion: nil)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "chatSelected") {
            let nextViewcontroller = segue.destinationViewController as! ChatViewController
            nextViewcontroller.pageViewController = self.pageViewController
            if(newChat == nil){
                //Normal segue after chat selection in list
                let path = self.chatTableView.indexPathForSelectedRow!
                nextViewcontroller.chat = chats[path.row]
            	chats[path.row].unreadMessageCount = 0
                chats[path.row].resetCoreUnreadCounter()
            }else if(newChat == true){
                //Segue after new user selection on map
                nextViewcontroller.chat = chats[0]
                chats[0].unreadMessageCount = 0
                chats[0].resetCoreUnreadCounter()
            }else{
                //Segue after selection on map of user with an already existing chat
                let chatAndIndex = Chat.getChatByUserId(clickedUserId!)
                nextViewcontroller.chat = chatAndIndex.0
                chatAndIndex.0?.resetCoreUnreadCounter()
                
            }
        }
    }
    
    func updateData(){
        account.refreshChats { (_) in
            self.refreshControl.endRefreshing()
            self.chatTableView.reloadData()
        }
    }
    
    
    /*
    ##################   WEB SOCKET   ##################
    */
    
    // Connect to the server through the websocket
    func connectToServer(){
        // Avoid multiple connections
        if(!self.isConnected) {
            self.socket.connect()
        }
    }
    
    // Disconnect from the server through the websocket
    func disconnectFromServer(){
        // Avoid multiple connections
        if(self.isConnected) {
            self.socket.disconnect()
        }
    }
    
    func addHandler() {
        
        socket.on("message-" + account.user.userId) {[weak self] data, ack in
            let json = JSON(data)
            let user_id = json[0]["user_id"].string
            
            let chatAndIndex = Chat.getChatByUserId(user_id!)
            
                // Message received for a conversation
                if let chat = Chat.getChatByUserId(user_id!).0 {
                    // Get other user data
                    let newMessage = ServerAPIController.createJSQMessage(user_id!, localMessage: json[0])
                    chat.allMessages.append(newMessage);
                    chat.updateLastMessage()
                    chat.unreadMessageCount++
                    
                    //Let's save the message in core data
                    chat.saveNewMessage(newMessage, userId: user_id!)
                    
                    //We need to put the chat on the top of the list
                    account.chats.removeAtIndex(chatAndIndex.1!)
                    account.chats.insert(chat, atIndex: 0)
                    
                    if(self!.chatTableView != nil){
                     self!.chatTableView.reloadData()
                    }
                }else{
                    account.fetchUserByID(user_id!, completion: { (result) -> Void in
                        let newUser = result
                        let newMessage = ServerAPIController.createJSQMessage(user_id!, localMessage: json[0])
                        let chat = Chat(user: newUser!, lastMessageText: newMessage.text, lastMessageSentDate: NSDate())
                        chat.allMessages.append(newMessage)
                        chat.updateLastMessage()
                        chat.unreadMessageCount++
                        
                        //we need to insert the new chat in the chat list
                        account.chats.insert(chat, atIndex: 0)
                        
                        self!.chatTableView.hidden = false
                        self!.defaultMessage.hidden = true
                        
                        //Lets save the new chat with the message added
                        chat.saveNewChat()
                        if(self!.chatTableView != nil){
                            self!.chatTableView.reloadData()
                        }
                    })
                }
            }
        }
}
