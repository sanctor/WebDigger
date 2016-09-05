//
//  ViewController.swift
//  WebDigger
//
//  Created by Serge Golubenko on 01.09.16.
//  Copyright © 2016 Serge Golubenko. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {

	@IBOutlet weak var urlField: UITextField!
	@IBOutlet weak var searchField: UITextField!
	@IBOutlet weak var depthLabel: UILabel!
	@IBOutlet weak var depthSlider: UISlider!
	@IBOutlet weak var threadsLabel: UILabel!
	@IBOutlet weak var threadsSlider: UISlider!
	@IBOutlet weak var resultsLabel: UILabel!
	@IBOutlet weak var resultsSlider: UISlider!
	@IBOutlet weak var settingsView: UIView!
	@IBOutlet weak var resultsView: UIView!
	@IBOutlet weak var resultsTable: UITableView!
	@IBOutlet weak var btnSearch: UIButton!
	@IBOutlet weak var activeThreadsLabel: UILabel!
	@IBOutlet weak var viewedPagesLabel: UILabel!
	@IBOutlet weak var resultedPagesLabel: UILabel!

	override func viewDidLoad() {
		super.viewDidLoad()
		urlField.text = "http://www.bbc.com/"
		searchField.text = "Ukraine"

		depthSlider.value = Float(WebDigger.shared.maxDepth)
		threadsSlider.value = Float(WebDigger.shared.maxThreads)
		resultsSlider.value = Float(WebDigger.shared.maxResults)

		depthLabel.text = "Search depth (\(WebDigger.shared.maxDepth)):"
		threadsLabel.text = "Max threads (\(WebDigger.shared.maxThreads)):"
		resultsLabel.text = "Max results (\(WebDigger.shared.maxResults)):"

		resultsView.hidden = true

		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(WebDigger.resultsUpdated(_:)), name: kNOTIFY_RESULTS_UPDATED, object: nil)
	}

	func resultsUpdated (notification: NSNotification) {
		dispatch_async(dispatch_get_main_queue(), {
			self.activeThreadsLabel.text = "Threads active: \(WebDigger.shared.threadsUsed)"
			self.viewedPagesLabel.text = "Pages viewed: \(WebDigger.shared.viewedPages)"
			self.resultedPagesLabel.text = "Pages with text: \(WebDigger.shared.resultedPages)"

			self.resultsTable.reloadData()

			if WebDigger.shared.stop {
				self.urlField.enabled = true
				self.searchField.enabled = true
				self.btnSearch.setTitle("Search", forState: UIControlState.Normal)
				UIApplication.sharedApplication().networkActivityIndicatorVisible = false

				let alert = UIAlertController(title: "Search finished", message: "Found \(WebDigger.shared.currentResults) occurences of text on \(WebDigger.shared.viewedPages) pages", preferredStyle: UIAlertControllerStyle.Alert)
				alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))

				self.presentViewController(alert, animated: true, completion: nil)
			}
		});
	}

	@IBAction func onSearch(sender: AnyObject) {
		if WebDigger.shared.stop {
			if urlField.text?.characters.count < 10 {
				urlField.becomeFirstResponder()
				return
			}

			if searchField.text?.characters.count < 3 {
				searchField.becomeFirstResponder()
				return
			}

			UIApplication.sharedApplication().networkActivityIndicatorVisible = true

			WebDigger.shared.searchString = searchField.text!
			WebDigger.shared.startSearchWith(urlField.text!)

			resultsView.hidden = false
			urlField.enabled = false
			searchField.enabled = false
			btnSearch.setTitle("Stop", forState: UIControlState.Normal)

			self.resultsTable.reloadData()

		} else {
			UIApplication.sharedApplication().networkActivityIndicatorVisible = false

			urlField.enabled = true
			searchField.enabled = true

			WebDigger.shared.stopSearch()
			btnSearch.setTitle("Search", forState: UIControlState.Normal)
		}

	}
	@IBAction func depthChanged(sender: AnyObject) {
		let slider: UISlider = sender as! UISlider
		WebDigger.shared.maxDepth = Int(slider.value)
		depthLabel.text = "Search depth (\(WebDigger.shared.maxDepth)):"
	}

	@IBAction func maxThreadsChanged(sender: AnyObject) {
		let slider: UISlider = sender as! UISlider
		WebDigger.shared.maxThreads = Int(slider.value)
		threadsLabel.text = "Max threads (\(WebDigger.shared.maxThreads)):"
	}

	@IBAction func maxResultsChanged(sender: AnyObject) {
		let slider: UISlider = sender as! UISlider
		WebDigger.shared.maxResults = Int(slider.value)
		resultsLabel.text = "Max results (\(WebDigger.shared.maxResults)):"
	}

	@IBAction func resultsTapped(sender: AnyObject) {
		if WebDigger.shared.stop {
			resultsView.hidden = true
		}
	}

// MARK: Text field delegate

	func textFieldShouldReturn(textField: UITextField) -> Bool {
		if urlField.text?.characters.count < 10 {
			urlField.becomeFirstResponder()
			return true
		}

		if searchField.text?.characters.count < 3 {
			searchField.becomeFirstResponder()
			return true
		}

		onSearch(textField)

		return true
	}

// MARK: Table Delegate

	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}

	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return WebDigger.shared.urlResults.values.count
	}

	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		var cell = tableView.dequeueReusableCellWithIdentifier("resultCell")
		if cell == nil {
			cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: "resultCell")
		}

		let result: URLSearchResult = Array(WebDigger.shared.urlResults.values)[indexPath.row]
		switch result.status {
		case .URLSearchStatusFinished:
			let img = UIImageView.init(image: UIImage.init(named: "checkmark"))
			img.tintColor = result.resultsCount > 0 ? UIColor.greenColor() : UIColor.orangeColor()
			cell?.accessoryView = img
		case .URLSearchStatusInProgress:
			let activity = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
			activity.startAnimating()
			cell?.accessoryView = activity
		case .URLSearchStatusError:
			let img = UIImageView.init(image: UIImage.init(named: "error"))
			img.tintColor = UIColor.redColor()
			cell?.accessoryView = img
		default:
			let img = UIImageView.init(image: UIImage.init(named: "delay"))
			img.tintColor = UIColor.darkGrayColor()
			cell?.accessoryView = img
		}
		cell?.textLabel?.text = result.urlString
		if result.statusString.characters.count > 0 {
			cell?.detailTextLabel?.text = result.statusString
		} else {
			cell?.detailTextLabel?.text = "Text found: \(result.resultsCount)"
		}

		return cell!
	}

	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		let result: URLSearchResult = Array(WebDigger.shared.urlResults.values)[indexPath.row]
		UIPasteboard.generalPasteboard().string = result.urlString
	}
}

