//
//  CloudQandATableViewController.swift
//  Pollster
//
//  Created by Michel Deiman on 24/10/2016.
//  Copyright © 2016 Michel Deiman. All rights reserved.
//

import UIKit
import CloudKit

class CloudQandATableViewController: QandATableViewController {
	
	// MARK: Model
	var ckQandARecord: CKRecord {
		get { return _ckQandARecord == nil ? CKRecord(recordType: Cloud.Entity.QandA) : _ckQandARecord! }
		set { _ckQandARecord = newValue }
	}

	// MARK: UITextViewDelegate
	override func textViewDidEndEditing(_ textView: UITextView) {
		super.textViewDidEndEditing(textView)
		iCloudUpdate()
	}
	
	// MARK: Private Implementation
	
	var _ckQandARecord: CKRecord? {
		didSet {
			let question = ckQandARecord[Cloud.Attribute.Question] as? String ?? ""
			let answers = ckQandARecord[Cloud.Attribute.Answers] as? [String] ?? []
			qanda = QandA(question: question, answers: answers)
			asking = ckQandARecord.wasCreatedByThisUser
		}
	}
	
	private let database = CKContainer.default().publicCloudDatabase
	
	@objc private func iCloudUpdate() {
		if !qanda.question.isEmpty && !qanda.answers.isEmpty {
			ckQandARecord[Cloud.Attribute.Question] = qanda.question as CKRecordValue?
			ckQandARecord[Cloud.Attribute.Answers] = qanda.answers as CKRecordValue?
			iCloudSave(record: ckQandARecord)
		}
	}
	
	private func iCloudSave(record: CKRecord) {
		database.save(record) { (savedRecord, error) in
			guard let error = error as? NSError else { return }
			switch error {
			case CKError.serverRecordChanged: break	// update by other user/device or asynchronously...
			default:
				self.retryAfter(error: error, withSelector: #selector(self.iCloudUpdate))
			}
		}
	}
	
	private func retryAfter(error: NSError?, withSelector selector: Selector) {
		if let retryInterval = error?.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
			DispatchQueue.main.async {
				Timer.scheduledTimer(timeInterval: retryInterval,
				                     target: self,
				                     selector: selector,
				                     userInfo: nil,
				                     repeats: false)
			}
		}
	}
	

}
