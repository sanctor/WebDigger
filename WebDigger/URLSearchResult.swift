//
//  URLSearchResult.swift
//  WebDigger
//
//  Created by Serge Golubenko on 05.09.16.
//  Copyright © 2016 Serge Golubenko. All rights reserved.
//

import UIKit

enum URLSearchStatus {
	case urlSearchStatusAdded
	case urlSearchStatusInProgress
	case urlSearchStatusFinished
	case urlSearchStatusError
}

class URLSearchResult: NSObject {
	var urlString: String = "";
	var level: Int = 0
	var resultsCount: Int = 0
	var status: URLSearchStatus = .urlSearchStatusAdded
	var statusString: String = ""

	init(aURLString: String) {
		urlString = aURLString
	}
}
