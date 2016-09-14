//
//  WebDigger.swift
//  WebDigger
//
//  Created by Serge Golubenko on 01.09.16.
//  Copyright © 2016 Serge Golubenko. All rights reserved.
//

import UIKit
import Foundation

let kNOTIFY_RESULTS_UPDATED = NSNotification.Name(rawValue: "resultsUpdatedNotification")

class WebDigger: NSObject {
    private static let instance : WebDigger = {
        let instance = WebDigger()
        return instance
    }()
	
	class var shared: WebDigger {
		get {
            return instance;
		}
	}

	var searchString: String = "swift"
	fileprivate var urlPools: Array<Set<String>>?
	fileprivate var urlDigged: Set<String>?
	var maxDepth = 1
	var maxThreads = 5
	var maxResults = 100
	var currentResults = 0
	var resultedPages = 0
	var threadsUsed = 0
	var stop = true
	var urlSession: URLSession?

	var urlResults: [String: URLSearchResult] = [:]

	let httpRegex: NSRegularExpression = try! NSRegularExpression.init(pattern: "https?:\\/\\/(www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{2,256}\\.[a-z]{2,6}\\b([-a-zA-Z0-9@:%_\\+.~#?&//=]*)", options: .caseInsensitive)

	var searchRegex: NSRegularExpression?

	var viewedPages: Int {
		get {
			return (urlDigged?.count)!
		}
	}

	override init() {
		super.init()

		NotificationCenter.default.addObserver(self, selector: #selector(WebDigger.resultsUpdated(_:)), name: kNOTIFY_RESULTS_UPDATED, object: nil)
	}

	func resultsUpdated (_ notification: Notification) {
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
			stopSearch()
		}

		while threadsUsed < maxThreads && !self.stop {
			var curLevel = 0

			var levelPool: Set<String> = []
			while curLevel < (urlPools?.count)! {
				levelPool = (self.urlPools?[curLevel])!
				if levelPool.count > 0 {
					break
				}
				curLevel += 1
			}

			if levelPool.count > 0 {
				searchWith(levelPool.first!)
			} else {
				stopSearch()
			}
		}
	}

	func startSearchWith(_ urlString: String) {
		urlResults = [:]
		urlPools = []
		urlDigged = []
		threadsUsed = 0
		currentResults = 0
		resultedPages = 0

		searchRegex = try! NSRegularExpression.init(pattern: self.searchString, options: .caseInsensitive)

		stop = false
        
		DispatchQueue.global().async {
			self.searchWith(urlString);
		}
	}

	func stopSearch() {
		stop = true
		urlSession?.invalidateAndCancel()
		urlSession = nil
	}

	func searchWith(_ urlString: String) {
		if stop { return }

		for (index, var urlPool) in (urlPools?.enumerated())! {
			urlPool.remove(urlString)
			urlPools![index] = urlPool
		}

		guard !(urlDigged?.contains(urlString))! else {
			return
		}

		urlDigged?.insert(urlString)
		if (urlResults[urlString] == nil) {
			urlResults[urlString] = URLSearchResult(aURLString: urlString)
		}
		urlResults[urlString]?.status = .urlSearchStatusInProgress

		let url: URL = URL(string: urlString)!

		if urlSession == nil {
			let sessionConfig = URLSessionConfiguration.default
			sessionConfig.httpMaximumConnectionsPerHost = self.maxThreads;
			sessionConfig.timeoutIntervalForResource = 20;
			sessionConfig.timeoutIntervalForRequest = 20;

			urlSession = URLSession(configuration: sessionConfig)

		}

		let task = urlSession!.dataTask(with: url, completionHandler: {
			(data, response, error) in

			self.threadsUsed -= 1

			guard let _ = self.urlResults[urlString] else {
				NotificationCenter.default.post(name: kNOTIFY_RESULTS_UPDATED, object: nil)
				return
			}

			let resultObject: URLSearchResult = self.urlResults[urlString]!

			if error != nil {
				resultObject.status = .urlSearchStatusError
				resultObject.statusString = (error?.localizedDescription)!

				NotificationCenter.default.post(name: kNOTIFY_RESULTS_UPDATED, object: nil)
				return
			}

			guard let _: Data = data, let _: URLResponse = response , error == nil else {
				resultObject.status = .urlSearchStatusError
				resultObject.statusString = (error?.localizedDescription)!

				NotificationCenter.default.post(name: kNOTIFY_RESULTS_UPDATED, object: nil)
				return
			}

			let dataString = String(data: data!, encoding: String.Encoding.utf8)
			if (dataString == nil) {
				resultObject.status = .urlSearchStatusError
				resultObject.statusString = NSLocalizedString("Cannot convert server response", comment: "")

				NotificationCenter.default.post(name: kNOTIFY_RESULTS_UPDATED, object: nil)
				return
			}

			var matches = self.searchRegex!.matches(in: dataString!, options: .withoutAnchoringBounds, range: NSMakeRange(0, (dataString?.characters.count)!))

			resultObject.status = .urlSearchStatusFinished
			resultObject.resultsCount = matches.count

			if resultObject.level < self.maxDepth && !self.stop {
				matches = self.httpRegex.matches(in: dataString!, options: .withoutAnchoringBounds, range: NSMakeRange(0, (dataString?.characters.count)!))

				var levelPool: Set<String> = []
				let level = resultObject.level
				if self.urlPools!.count > level {
					levelPool = self.urlPools![level]
				}

				for match in matches {
					let matchRange = match.range
					var urlStr = (dataString! as NSString).substring(with: matchRange)
					if urlStr.hasSuffix("/") {
						urlStr = urlStr.substring(to: urlStr.characters.index(before: urlStr.endIndex))
					}

					if self.urlResults[urlStr] == nil {
						let searchResult: URLSearchResult = URLSearchResult(aURLString: urlStr)
						searchResult.level = level + 1
						self.urlResults[urlStr] = searchResult

						levelPool.insert(urlStr)
					}
				}
				if self.urlPools!.count > level {
					self.urlPools![level] = levelPool
				} else {
					self.urlPools?.append(levelPool)
				}
			}

			NotificationCenter.default.post(name: kNOTIFY_RESULTS_UPDATED, object: nil)
		}) 

		threadsUsed += 1
		task.resume()
	}

}
