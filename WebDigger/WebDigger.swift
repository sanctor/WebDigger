//
//  WebDigger.swift
//  WebDigger
//
//  Created by Serge Golubenko on 01.09.16.
//  Copyright © 2016 Serge Golubenko. All rights reserved.
//

import UIKit
import Foundation

let kNOTIFY_RESULTS_UPDATED = "resultsUpdatedNotification"

class WebDigger: NSObject {
	class var shared: WebDigger {
		get {
			struct Static {
				static var instance: WebDigger? = nil
				static var token: dispatch_once_t = 0
			}
			dispatch_once(&Static.token, {
				Static.instance = WebDigger()
			})
			return Static.instance!
		}
	}

	var searchString: String = "swift"
	private var urlPools: Array<NSMutableSet> = []
	private var urlDigged: NSMutableSet = []
	var maxDepth = 1
	var maxThreads = 5
	var maxResults = 100
	var currentResults = 0
	var resultedPages = 0
	var threadsUsed = 0
	var stop = true

	var urlResults: [String: URLSearchResult] = [:]

	var viewedPages: Int {
		get {
			return urlDigged.count
		}
	}

	override init() {
		super.init()

		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(WebDigger.resultsUpdated(_:)), name: kNOTIFY_RESULTS_UPDATED, object: nil)
	}

	func resultsUpdated (notification: NSNotification) {
		var rs = 0
		var rp = 0

		for (_, urlResult) in urlResults {
			rs += urlResult.resultsCount
			if urlResult.resultsCount > 0 {
				rp += 1
			}
		}
		currentResults = rs
		resultedPages = rp

		if currentResults >= maxResults {
			self.stop = true
		}

		while threadsUsed < maxThreads && !self.stop {
			var curLevel = 0

			var levelPool: NSMutableSet = []
			while curLevel < urlPools.count {
				levelPool = self.urlPools[curLevel]
				if levelPool.count > 0 {
					break
				}
				curLevel += 1
			}

			if levelPool.count > 0 {
				searchWith(levelPool.anyObject() as! String)
			} else {
				stop = true
			}
		}
	}

	func startSearchWith(urlString: String) {
		urlResults = [:]
		urlPools = []
		urlDigged = []
		threadsUsed = 0
		currentResults = 0
		resultedPages = 0

		stop = false

		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
			self.searchWith(urlString);
		});

	}

	func stopSearch() {
		stop = true
	}

	func searchWith(urlString: String) {
		if stop { return }

		for urlPool in urlPools {
			urlPool.removeObject(urlString)
		}

		guard !urlDigged.containsObject(urlString) else {
			NSNotificationCenter.defaultCenter().postNotificationName(kNOTIFY_RESULTS_UPDATED, object: nil)
			return
		}

		urlDigged.addObject(urlString)
		if (urlResults[urlString] == nil) {
			urlResults[urlString] = URLSearchResult(aURLString: urlString)
		}
		urlResults[urlString]?.status = .URLSearchStatusInProgress

		let url: NSURL = NSURL(string: urlString)!
		let session = NSURLSession.sharedSession()

		let task = session.dataTaskWithURL(url) {
			(let data, let response, let error) in

			self.threadsUsed -= 1

			guard let _ = self.urlResults[urlString] else {
				NSNotificationCenter.defaultCenter().postNotificationName(kNOTIFY_RESULTS_UPDATED, object: nil)
				return
			}

			let resultObject: URLSearchResult = self.urlResults[urlString]!

			if error != nil {
				resultObject.status = .URLSearchStatusError
				resultObject.statusString = (error?.localizedDescription)!

				NSNotificationCenter.defaultCenter().postNotificationName(kNOTIFY_RESULTS_UPDATED, object: nil)
				return
			}

			guard let _: NSData = data, let _: NSURLResponse = response where error == nil else {
				resultObject.status = .URLSearchStatusError
				resultObject.statusString = (error?.localizedDescription)!

				NSNotificationCenter.defaultCenter().postNotificationName(kNOTIFY_RESULTS_UPDATED, object: nil)
				return
			}

			let dataString = String(data: data!, encoding: NSUTF8StringEncoding)
			if (dataString == nil) {
				resultObject.status = .URLSearchStatusError
				resultObject.statusString = NSLocalizedString("Cannot convert server response", comment: "")

				NSNotificationCenter.defaultCenter().postNotificationName(kNOTIFY_RESULTS_UPDATED, object: nil)
				return
			}

			var pattern = self.searchString
			var regex = try! NSRegularExpression.init(pattern: pattern, options: .CaseInsensitive)
			var matches = regex.matchesInString(dataString!, options: .WithoutAnchoringBounds, range: NSMakeRange(0, (dataString?.characters.count)!))

			resultObject.status = .URLSearchStatusFinished
			resultObject.resultsCount = matches.count

			if resultObject.level < self.maxDepth && !self.stop {
				pattern = "https?:\\/\\/(www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{2,256}\\.[a-z]{2,6}\\b([-a-zA-Z0-9@:%_\\+.~#?&//=]*)"
				regex = try! NSRegularExpression.init(pattern: pattern, options: .CaseInsensitive)
				matches = regex.matchesInString(dataString!, options: .WithoutAnchoringBounds, range: NSMakeRange(0, (dataString?.characters.count)!))

				var levelPool: NSMutableSet = []
				let level = resultObject.level
				if self.urlPools.count > level {
					levelPool = self.urlPools[level]
				} else {
					self.urlPools.append(levelPool)
				}

				for match in matches {
					let matchRange = match.range
					var urlStr = (dataString! as NSString).substringWithRange(matchRange)
					if urlStr.hasSuffix("/") {
						urlStr = urlStr.substringToIndex(urlStr.endIndex.predecessor())
					}

					if self.urlResults[urlStr] == nil {
						let searchResult: URLSearchResult = URLSearchResult(aURLString: urlStr)
						searchResult.level = level + 1
						self.urlResults[urlStr] = searchResult

						levelPool.addObject(urlStr)
					}
				}

			}

			NSNotificationCenter.defaultCenter().postNotificationName(kNOTIFY_RESULTS_UPDATED, object: nil)

		}

		threadsUsed += 1
		task.resume()
	}

}
