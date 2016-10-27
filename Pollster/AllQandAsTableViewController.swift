////////////////////////////////////////////////////////////////////////////
//  AllQandAsTableViewController.swift
//  Pollster
//
//  Created by CS193p Instructor.
//  Copyright © 2016 Stanford University. All rights reserved.
//
//  Converted to Swift 3.0 by Michel Deiman on 24/10/2016.
//  Copyright © 2016 Michel Deiman. All rights reserved.
////////////////////////////////////////////////////////////////////////////

import UIKit
import CloudKit
import UserNotifications


class AllQandAsTableViewController: UITableViewController {

	// MARK: Model
	
	var allQandAs = [CKRecord]() { didSet { tableView.reloadData() } }
	
	// MARK: View Controller Lifecycle
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		fetchAllQandAs()
		iCloudSubscribeToQandAs()
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		iCloudUnsubscribeToQandAs()
	}
	
	override func viewDidLoad() {
	}
	
	private let database = CKContainer.default().publicCloudDatabase
	
	private func fetchAllQandAs() {
		let predicate = NSPredicate(format: "TRUEPREDICATE")
		let query = CKQuery(recordType: Cloud.Entity.QandA, predicate: predicate)
		query.sortDescriptors = [NSSortDescriptor(key: Cloud.Attribute.Question, ascending: true)]
		database.perform(query, inZoneWith: nil) { (records, error) in
			if records != nil {
				DispatchQueue.main.async {
					self.allQandAs = records!
				}
			}
		}
	}
	
	// MARK: Subscription
	
	func assets() {
		let url = URL(fileURLWithPath: "")
		let asset = CKAsset(fileURL: url)
		let record = CKRecord(recordType: Cloud.Entity.QandA)
		record["image"] = asset
		database.save(record) { savedRecord, error in
			if error != nil {
				// handle the error ...
			}
		}
		
	}
	
	private let subscriptionID = "All QandA Creations and Deletions"
	private var cloudKitObserver: NSObjectProtocol?
	
	private func iCloudSubscribeToQandAs() {
		let predicate = NSPredicate(format: "TRUEPREDICATE")
		let subscription = CKQuerySubscription(
			recordType: Cloud.Entity.QandA,
			predicate: predicate,
			subscriptionID: self.subscriptionID,
			options: [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate]
		)
		// subscription.notificationInfo = ... what sort of notification??
		let notification = CKNotificationInfo()
		notification.alertBody = "There is an update...."
		notification.soundName = "default"
		notification.shouldBadge  = true
		notification.desiredKeys = [Cloud.Attribute.Question, Cloud.Attribute.Answers]
		subscription.notificationInfo = notification
		
		database.save(subscription)
		{	(savedSubscription, error) in
			if let error = error, let ckError = error as? CKError {
				switch ckError.code {
				case .serverRejectedRequest: break	// handle errors
				default: break;
				}
			}
		}
		cloudKitObserver = NotificationCenter.default.addObserver(
			forName: NSNotification.Name(rawValue: CloudKitNotifications.NotificationReceived),
			object: nil,
			queue: OperationQueue.main,
			using: { notification in
				if let ckqn = notification.userInfo?[CloudKitNotifications.NotificationKey] as? CKQueryNotification {
					self.iCloudHandleSubscriptionNotification(ckqn: ckqn)
				}
			}
		)
	}
	
	private func iCloudUnsubscribeToQandAs() {
		if let observer = cloudKitObserver {
			NotificationCenter.default.removeObserver(observer)
			cloudKitObserver = nil
		}
//		database.delete(withSubscriptionID: self.subscriptionID) { (subscription, error) in
//			// handle it
//		}
	}

	private func iCloudHandleSubscriptionNotification(ckqn: CKQueryNotification)
	{
		if ckqn.subscriptionID == self.subscriptionID, let recordID = ckqn.recordID {
			switch ckqn.queryNotificationReason {
			case .recordCreated:
				database.fetch(withRecordID: recordID) { (record, error) in
					if record != nil {
						DispatchQueue.main.async {
							self.allQandAs = (self.allQandAs + [record!]).sorted {
								return $0.question < $1.question
							}
						}
					}
				}
			case .recordDeleted:
				DispatchQueue.main.async {
					self.allQandAs = self.allQandAs.filter { $0.recordID != recordID }
				}
			case .recordUpdated:
				database.fetch(withRecordID: recordID) { (record, error) in
					if record != nil {
						DispatchQueue.main.async {
							for index in 0..<self.allQandAs.count {
								if self.allQandAs[index].recordID == recordID {
									self.allQandAs[index] = record!
									break
								}
							}
						}
					}
				}
			}
		}
		
	}
	

	// MARK: UITableViewDataSource
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return allQandAs.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "QandA Cell", for: indexPath)
		cell.textLabel?.text = allQandAs[indexPath.row].question
		return cell
	}

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return allQandAs[indexPath.row].wasCreatedByThisUser
	}
	
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath)
	{
		if editingStyle == .delete {
			let record = allQandAs[indexPath.row]
			database.delete(withRecordID: record.recordID) { [unowned self] (deletedRecord, error) in
				if deletedRecord != nil {
					DispatchQueue.main.async { self.allQandAs.remove(at: indexPath.row) }
				}
				if error != nil { print("error not nil at record deletion")}
			}
		}
	}
	
	// MARK: Navigation
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "Show QandA" {
			if let ckQandATVC = segue.destination as? CloudQandATableViewController {
				if let cell = sender as? UITableViewCell, let indexPath = tableView.indexPath(for: cell) {
					ckQandATVC.ckQandARecord = allQandAs[indexPath.row]
				} else {
					ckQandATVC.ckQandARecord = CKRecord(recordType: Cloud.Entity.QandA)
				}
			}
		}
	}
	
}
