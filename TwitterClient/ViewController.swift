//
//  ViewController.swift
//  TwitterClient
//
//  Created by 姜 修章 on 2015/01/08.
//  Copyright (c) 2015年 姜 修章. All rights reserved.
//

import UIKit
import Social
import Accounts

class ViewController: UIViewController, UITableViewDataSource {

    let SCREEN = UIScreen.mainScreen().bounds.size
    
    @IBOutlet var _tableView: UITableView?
    var _accountStore: ACAccountStore?
    var _account: ACAccount?
    var _items = [Status]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.title = "Twitter クライアント"
        initTwitterAccount()
    }

    @IBAction func onClick(sender: UIBarButtonItem) {
        if _account == nil {
            initTwitterAccount()
            return
        }
        if sender.tag == 0 {
            timeline()
        } else if sender.tag == 1 {
            twit()
        }
    }
    
    func makeLabel(frame: CGRect, text: NSString, font: UIFont) -> UILabel {
        let label = UILabel()
        label.frame = frame
        label.text = text
        label.font = font
        label.textColor = UIColor.blackColor()
        label.backgroundColor = UIColor.clearColor()
        label.textAlignment = NSTextAlignment.Left
        label.lineBreakMode = NSLineBreakMode.ByWordWrapping
        label.numberOfLines = 0
        return label
    }
    
    func makeImageView(frame: CGRect, image: UIImage?) -> UIImageView {
        let imageView = UIImageView()
        imageView.frame = frame
        imageView.image = image
        return imageView
    }
    
    func showAlert(title: NSString?, text: NSString?) {
        let alert = UIAlertController(title: title, message: text, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func setIndicator(indicator: Bool) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = indicator
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func initTwitterAccount() {
        // TODO TwitterAccount取得処理
        _account = nil
        _accountStore = ACAccountStore()
        let twitterType = _accountStore?.accountTypeWithAccountTypeIdentifier(ACAccountTypeIdentifierTwitter)
        _accountStore?.requestAccessToAccountsWithType(twitterType, options: nil) {(granted, error) in
            if granted {
                let accounts = self._accountStore?.accountsWithAccountType(twitterType)
                if accounts!.count > 0 {
                    self._account = accounts![0] as? ACAccount
                    self.timeline()
                    return
                }
            }
            dispatch_async(dispatch_get_main_queue(), {
                self.showAlert(nil, text: "Twitterアカウントが登録されていません")
            })
        }
    }
    
    func loadIcon(status: Status) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let request = NSURLRequest(URL: NSURL(string: status.iconURL)!, cachePolicy: NSURLRequestCachePolicy.UseProtocolCachePolicy, timeoutInterval: 30.0)
            let data = NSURLConnection.sendSynchronousRequest(request, returningResponse: nil, error: nil)
            
            // テーブル更新
            dispatch_async(dispatch_get_main_queue()) {
                status.icon = UIImage(data: data!)
                self._tableView?.reloadData()
            }
        }
    }
    
    func timeline() {
        self.setIndicator(true)
        
        let url = NSURL(string: "https://api.twitter.com/1.1/statuses/home_timeline.json")
        let params: Dictionary<NSObject, AnyObject!> = ["count": "20"]
        let timeline = SLRequest(forServiceType: SLServiceTypeTwitter, requestMethod: SLRequestMethod.GET, URL: url, parameters: params)
        timeline.account = self._account
        timeline.performRequestWithHandler(){(responseData: NSData!, urlResponse: NSHTTPURLResponse!, error: NSError!) in
            var jsonError: NSError? = nil
            let obj : AnyObject? = NSJSONSerialization.JSONObjectWithData(responseData!, options: nil, error: &jsonError)
            
            if error != nil {
                self.showAlert(nil, text: "通信に失敗しました")
            }else if obj == nil || jsonError != nil {
                self.showAlert(nil, text: "パースに失敗しました")
            }else if !obj!.isKindOfClass(NSArray) {
                self.showAlert(nil, text: "パースに失敗しました")
            } else {
                self._items.removeAll(keepCapacity: false)
                let statuses = obj as NSArray
                for var i = 0; i < statuses.count; i++ {
                    let item = Status()
                    let status = statuses[i] as NSDictionary
                    let user = status["user"] as NSDictionary
                    item.text = status["text"] as String
                    item.name = user["screen_name"] as String
                    item.iconURL = user["profile_image_url"] as String
                    self.loadIcon(item)
                    self._items.append(item)
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                let tableView = self._tableView
                tableView?.reloadData()
            })
            
            self.setIndicator(false)
        }
    }

    func twit() {
        let twitterCtl = SLComposeViewController(forServiceType: SLServiceTypeTwitter)
        self.presentViewController(twitterCtl, animated: true, completion: nil)
    }
    
    func data2str(data: NSData) -> NSString {
        return NSString(data: data, encoding: NSUTF8StringEncoding)!
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let status = _items[indexPath.row]
        let label = makeLabel(CGRectMake(60, 30, SCREEN.width - 70, 1024), text: status.text, font: UIFont.systemFontOfSize(14))
        label.sizeToFit()
        let height = 30 + label.frame.size.height + 10
        return height < 60 ? 60 : height
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _items.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell? = tableView.dequeueReusableCellWithIdentifier("table_cell") as? UITableViewCell
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "table_cell")
            
            // アイコンの追加
            let imgIcon = makeImageView(CGRectMake(10, 10, 40, 40), image: nil)
            imgIcon.tag = 1
            cell!.contentView.addSubview(imgIcon)
            
            // 名前の追加
            let lblName = makeLabel(CGRectMake(60, 10, 250, 16), text: "", font: UIFont.boldSystemFontOfSize(16))
            lblName.tag = 2
            cell!.contentView.addSubview(lblName)
            
            // テキストの追加
            let lblText = makeLabel(CGRectMake(60, 30, 320, 1024), text: "", font: UIFont.systemFontOfSize(14))
            lblText.tag = 3
            cell!.contentView.addSubview(lblText)
        }
        if _items.count <= indexPath.row {return cell!}
        
        // ステータスの取得
        let status = _items[indexPath.row]
        
        // アイコンの指定
        let imgIcon = cell!.contentView.viewWithTag(1) as UIImageView
        imgIcon.image = status.icon
        
        // 名前の指定
        let lblName = cell!.contentView.viewWithTag(2) as UILabel
        lblName.text = status.name
        
        // テキストの追加
        let lblText = cell!.contentView.viewWithTag(3) as UILabel
        lblText.text = status.text
        lblText.frame = CGRectMake(60, 30, SCREEN.width - 70, 1024)
        lblText.sizeToFit()
        return cell!
    }
}