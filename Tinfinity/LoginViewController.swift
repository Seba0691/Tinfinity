//
//  LoginViewController.swift
//  Tinfinity
//
//  Created by Alberto Fumagalli on 22/04/15.
//  Copyright (c) 2015 Sebastiano Mariani. All rights reserved.
//

import UIKit
import FBSDKCoreKit
import FBSDKLoginKit

class LoginViewController: UIViewController, FBSDKLoginButtonDelegate{
    

    @IBOutlet weak var loadingMessage: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loginButton: FBSDKLoginButton!
    var api: ServerAPIController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        loginButton.delegate = self
        self.view.backgroundColor = UIColor(red: 247/255, green: 246/255, blue: 243/255, alpha: 1)
        self.stopLoading()
        let minute: NSTimeInterval = 60, hour = minute * 60, _ = hour * 24
        
        //Controlliamo se è già presente un token facebook
        if (FBSDKAccessToken.currentAccessToken() != nil && account.token == nil){
            
            self.loading()
            
            //instantiating the apicontroller with the current access token to authenticate with the server
            api = ServerAPIController(FBAccessToken: FBSDKAccessToken.currentAccessToken().tokenString)
            api?.retrieveProfileFromServer({ (result) -> Void in
                //If the user is still nil it means the request to the server did not succeded, we need to understand if it's an internet issue or server issue
                if(result == false){
                    self.checkLoginProblem(false)
                }
                else{
                    //If there is already a fb token, we already got the chat history from the server, so we only check if there are chats in local db
                    Chat.loadChatsFromCore()
                    for chat in account.chats{
                        chat.fetchNewMessages({ (result) -> Void in
                        })
                    }
                    account.checkNewChat({ (result) -> Void in
                        account.updateRelationships()
                        self.performSegueWithIdentifier("loginExecuted", sender: self)
                    })
                    
                    return
                }
            })
        }
        else{
            //loginButton.center = self.view.center
            loginButton.readPermissions = ["public_profile", "email", "user_friends","user_photos","user_birthday"]
            loginButton.delegate = self
        }
    }
    
    func loading() {
        self.activityIndicator.startAnimating()
        self.activityIndicator.hidden = false
        self.loadingMessage.hidden = false
        self.view.userInteractionEnabled = false
        self.loginButton.hidden = true
    }
    
    func stopLoading() {
        self.activityIndicator.stopAnimating()
        self.activityIndicator.hidden = true
        self.loadingMessage.hidden = true
        self.view.userInteractionEnabled = true
        self.loginButton.hidden = false
    }
    
    func loginButton(loginButton: FBSDKLoginButton!, didCompleteWithResult result: FBSDKLoginManagerLoginResult!, error: NSError!) {
        if ((error) != nil) {
            // Process error
            print("Errore FB: ")
            print(error)
        }
        else if result.isCancelled {
            // Handle cancellations
            print("cancelled")
        }
        else {
            self.loading()
            //instatiating the apicontroller with the current access token to authenticate with the server
            api = ServerAPIController(FBAccessToken: FBSDKAccessToken.currentAccessToken().tokenString)
            api?.retrieveProfileFromServer({ (result) -> Void in
                //If the user is still nil it means the request to the server did not succeded, we need to understand if it's an internet issue or server issue
                if(result == false){
                    self.checkLoginProblem(true)
                }
                else{
                    self.api?.retriveChatHistory(account.user.userId, completion: { (result) -> Void in
                        self.performSegueWithIdentifier("loginExecuted", sender: self)
                    })
                    
                    return
                }
            })
        }
    }
    
    func loginButtonDidLogOut(loginButton: FBSDKLoginButton!) {
       
    }
       
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        
    }
    
    func checkLoginProblem(newLogin: Bool){
        
        let tryAgainAction = UIAlertAction(title: "Try Again", style: .Default){ (_) -> Void in
            
            self.api?.retrieveProfileFromServer({ (result) -> Void in
            	if(result == false){
            	    self.checkLoginProblem(newLogin)
            	}else{
                    if(newLogin == true){
                        self.loading()
                        self.api?.retriveChatHistory(account.user.userId, completion: { (result) -> Void in
                            self.stopLoading()
                            self.performSegueWithIdentifier("loginExecuted", sender: self)
                        })

					}else{
                        Chat.loadChatsFromCore()
                        for chat in account.chats{
                            chat.fetchNewMessages({ (result) -> Void in
                            })
                        }
                        account.checkNewChat({ (result) -> Void in
                            account.updateRelationships()
                            self.loading()
                            self.performSegueWithIdentifier("loginExecuted", sender: self)
                        })

					}
            	}
        	})
        }
        
        let connectionError = UIAlertController(title: "", message: "", preferredStyle:.Alert)
        
        connectionError.addAction(tryAgainAction)
        
        if Reachability.isConnectedToNetwork() == false {            
            connectionError.title = "No Internet Connection"
            connectionError.message = "Make sure your device is connected to the internet."
        } else {
            connectionError.title = "Server offline"
            connectionError.message = "It seems that our server is offline. Please, try again later."
        }
        
        self.presentViewController(connectionError, animated: true, completion: nil)
        
    }
    
}
