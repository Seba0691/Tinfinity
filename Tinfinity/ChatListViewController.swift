//
//  ChatListViewController.swift
//  tinFinity
//
//  Created by Alberto Fumagalli on 16/02/15.
//  Copyright (c) 2015 Alberto Fumagalli. All rights reserved.
//

import UIKit

class ChatListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    
    @IBOutlet weak var homeButton: UIButton!
    @IBOutlet weak var chatTableView: UITableView!
    
    var chats: [Chat] { return account.chats }
    var imageCache = [String:UIImage]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.view.backgroundColor = UIColor(red: 247/255, green: 246/255, blue: 243/255, alpha: 1)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
   func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chats.count
        
    }
    
   func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    
   func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        //we need to obtain the cell to set his values
        let cell: ChatCustomCell = chatTableView.dequeueReusableCellWithIdentifier("chatCell") as! ChatCustomCell
        let chat = chats[indexPath.row]        
        
        if (chat.user.imageUrl != nil){
            // Immagine già recuperata, usiamola
            if let img = imageCache[chat.user.imageUrl!] {
                cell.chatAvatar.image = img
            } else {
                let request: NSURLRequest = NSURLRequest(URL: NSURL(string: chat.user.imageUrl!)!)
                let mainQueue = NSOperationQueue.mainQueue()
                NSURLConnection.sendAsynchronousRequest(request, queue: mainQueue, completionHandler: {     (response, data, error) -> Void in
                    if error == nil {
                        // Convert the downloaded data in to a UIImage object
                        let image = UIImage(data: data)
                        //Store in our cache the image
                        self.imageCache[chat.user.imageUrl!] = image
                        // Update the cell
                        dispatch_async(dispatch_get_main_queue(), {
                            if let cellToUpdate = tableView.cellForRowAtIndexPath(indexPath) {
                                cellToUpdate.imageView?.image = image
                            }
                        })
                        tableView.reloadData()
                    }
                    else {
                        println("Error: \(error.localizedDescription)")
                    }
                })
            }
        }else{
            cell.imageView?.image = UIImage(named: "Blank52")
        }
        
        //Now we need to make the chatAvatar look round
        /*var frame = cell.chatAvatar.frame
        let imageSize = 55 as CGFloat
        frame.size.height = imageSize
        frame.size.width  = imageSize
        cell.chatAvatar.frame = frame
        cell.chatAvatar.layer.cornerRadius = imageSize / 2.0
        cell.chatAvatar.clipsToBounds = true*/
        
        cell.nameLabel.text = chat.user.name
        cell.messageLabel.text = chat.lastMessageText
        
        return cell
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "chatSelected") {
                let path = self.chatTableView.indexPathForSelectedRow()!
                let nextViewcontroller = segue.destinationViewController as! ChatViewController
                nextViewcontroller.chat = chats[path.row]
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        self.navigationController?.navigationBarHidden = true
    }

}
