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

		resultsView.isHidden = true

		NotificationCenter.default.addObserver(self, selector: #selector(WebDigger.resultsUpdated(_:)), name: kNOTIFY_RESULTS_UPDATED, object: nil)
	}

	func resultsUpdated (_ notification: Notification) {
		DispatchQueue.main.async(execute: {
			self.activeThreadsLabel.text = "Threads active: \(WebDigger.shared.threadsUsed)"
			self.viewedPagesLabel.text = "Pages viewed: \(WebDigger.shared.viewedPages)"
			self.resultedPagesLabel.text = "Pages with text: \(WebDigger.shared.resultedPages)"

			self.resultsTable.reloadData()

			if WebDigger.shared.stop && WebDigger.shared.threadsUsed == 0 {
				self.urlField.isEnabled = true
				self.searchField.isEnabled = true
				self.btnSearch.setTitle("Search", for: UIControlState())
				UIApplication.shared.isNetworkActivityIndicatorVisible = false

				let alert = UIAlertController(title: "Search finished", message: "Found \(WebDigger.shared.currentResults) occurences of text on \(WebDigger.shared.viewedPages) pages", preferredStyle: UIAlertControllerStyle.alert)
				alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default, handler: nil))

				self.present(alert, animated: true, completion: nil)
			}
		});
	}

	@IBAction func onSearch(_ sender: AnyObject) {
		if WebDigger.shared.stop {
			if (urlField.text?.characters.count)! < 10 {
				urlField.becomeFirstResponder()
				return
			}

			if (searchField.text?.characters.count)! < 3 {
				searchField.becomeFirstResponder()
				return
			}

			UIApplication.shared.isNetworkActivityIndicatorVisible = true

			WebDigger.shared.searchString = searchField.text!
			WebDigger.shared.startSearchWith(urlField.text!)

			resultsView.isHidden = false
			urlField.isEnabled = false
			searchField.isEnabled = false
			btnSearch.setTitle("Stop", for: UIControlState())

			self.resultsTable.reloadData()

		} else {
			UIApplication.shared.isNetworkActivityIndicatorVisible = false

			urlField.isEnabled = true
			searchField.isEnabled = true

			WebDigger.shared.stopSearch()
			btnSearch.setTitle("Search", for: UIControlState())
		}

	}
	@IBAction func depthChanged(_ sender: AnyObject) {
		let slider: UISlider = sender as! UISlider
		WebDigger.shared.maxDepth = Int(slider.value)
		depthLabel.text = "Search depth (\(WebDigger.shared.maxDepth)):"
	}

	@IBAction func maxThreadsChanged(_ sender: AnyObject) {
		let slider: UISlider = sender as! UISlider
		WebDigger.shared.maxThreads = Int(slider.value)
		threadsLabel.text = "Max threads (\(WebDigger.shared.maxThreads)):"
	}

	@IBAction func maxResultsChanged(_ sender: AnyObject) {
		let slider: UISlider = sender as! UISlider
		WebDigger.shared.maxResults = Int(slider.value)
		resultsLabel.text = "Max results (\(WebDigger.shared.maxResults)):"
	}

	@IBAction func resultsTapped(_ sender: AnyObject) {
		if WebDigger.shared.stop {
			resultsView.isHidden = true
		}
	}

// MARK: Text field delegate

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		if (urlField.text?.characters.count)! < 10 {
			urlField.becomeFirstResponder()
			return true
		}

		if (searchField.text?.characters.count)! < 3 {
			searchField.becomeFirstResponder()
			return true
		}

		onSearch(textField)

		return true
	}

// MARK: Table Delegate

	func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return WebDigger.shared.urlResults.values.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		var cell = tableView.dequeueReusableCell(withIdentifier: "resultCell")
		if cell == nil {
			cell = UITableViewCell(style: UITableViewCellStyle.subtitle, reuseIdentifier: "resultCell")
		}

		let result: URLSearchResult = Array(WebDigger.shared.urlResults.values)[(indexPath as NSIndexPath).row]
		switch result.status {
		case .urlSearchStatusFinished:
			let img = UIImageView.init(image: UIImage.init(named: "checkmark"))
			img.tintColor = result.resultsCount > 0 ? UIColor.green : UIColor.orange
			cell?.accessoryView = img
		case .urlSearchStatusInProgress:
			let activity = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
			activity.startAnimating()
			cell?.accessoryView = activity
		case .urlSearchStatusError:
			let img = UIImageView.init(image: UIImage.init(named: "error"))
			img.tintColor = UIColor.red
			cell?.accessoryView = img
		default:
			let img = UIImageView.init(image: UIImage.init(named: "delay"))
			img.tintColor = UIColor.darkGray
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

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let result: URLSearchResult = Array(WebDigger.shared.urlResults.values)[(indexPath as NSIndexPath).row]
		UIPasteboard.general.string = result.urlString
	}
}

