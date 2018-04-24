//
//  OPDSRootTableViewController.swift
//  r2-testapp-swift
//
//  Created by Geoffrey Bugniot on 23/04/2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import UIKit
import R2Shared
import ReadiumOPDS
import PromiseKit

enum FeedBrowsingState {
    case Navigation
    case Publication
    case MixedGroup
    case MixedNavigationPublication
    case MixedNavigationGroupPublication
    case None
}

class OPDSRootTableViewController: UITableViewController {
    
    var originalFeedURL: URL?
    var currentFeedURL: URL?
    var nextPageURL: URL?
    
    var feed: Feed?
    
    var browsingState: FeedBrowsingState = .None

    override func viewDidLoad() {
        super.viewDidLoad()
        parseFeed()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        tableView.reloadData()
    }
    
    // MARK: - OPDS feed parsing
    
    func parseFeed() {
        if let url = originalFeedURL {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            firstly {
                OPDSParser.parseURL(url: url)
                }.then { newFeed -> Void in
                    self.feed = newFeed
                    self.finishFeedInitialization()
            }
        }
    }
    
    func finishFeedInitialization() {
        if let feed = feed {
            navigationItem.title = feed.metadata.title
            self.nextPageURL = self.findNextPageURL(feed: feed)
            
            if feed.facets.count > 0 {
                let filterButton = UIBarButtonItem(title: "Filter",
                                                   style: UIBarButtonItemStyle.plain,
                                                   target: self,
                                                   action: #selector(OPDSRootTableViewController.filterMenuClicked))
                navigationItem.rightBarButtonItem = filterButton
            }
            
            if feed.navigation.count > 0 && feed.groups.count == 0 && feed.publications.count == 0 {
                browsingState = .Navigation
            } else if feed.publications.count > 0 && feed.groups.count == 0 && feed.navigation.count == 0 {
                browsingState = .Publication
                tableView.separatorStyle = .none
                tableView.isScrollEnabled = false
            } else if feed.groups.count > 0 && feed.publications.count == 0 && feed.navigation.count == 0 {
                browsingState = .MixedGroup
            } else if feed.navigation.count > 0 && feed.groups.count == 0 && feed.publications.count > 0 {
                browsingState = .MixedNavigationPublication
            } else if feed.navigation.count > 0 && feed.groups.count > 0 && feed.publications.count > 0 {
                browsingState = .MixedNavigationGroupPublication
            } else {
                browsingState = .None
            }
            
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
            
            tableView.reloadData()
        }
    }
    
    func findNextPageURL(feed: Feed) -> URL? {
        for link in feed.links {
            for rel in link.rel {
                if rel == "next" {
                    return URL(string: link.href!)
                }
            }
        }
        return nil
    }
    
    public func loadNextPage(completionHandler: @escaping (Feed?) -> ()) {
//        if !self.isFeedInitialized || self.isLoadingNextPage || nextPageURL == nil {
//            return
//        }
//        self.isLoadingNextPage = true
        
        if let nextPageURL = nextPageURL {
            firstly {
                OPDSParser.parseURL(url: nextPageURL)
                }.then { newFeed -> Void in
                    self.nextPageURL = self.findNextPageURL(feed: newFeed)
                    self.feed?.publications.append(contentsOf: newFeed.publications)
                    //self.changeFeed(newFeed: self.feed!) // changing to the ORIGINAL feed, now with more publications
                    //self.feed = newFeed
                    completionHandler(self.feed)
                }.always {
                    //self.isLoadingNextPage = false
            }
        }
        
    }
    
    //MARK: - Facets
    
    func filterMenuClicked(_ sender: UIBarButtonItem) {
//        if (!isFeedInitialized) {
//            return
//        }
        let tableViewController = OPDSFacetTableViewController(feed: feed!, rootViewController: self)
        tableViewController.modalPresentationStyle = UIModalPresentationStyle.popover

        present(tableViewController, animated: true, completion: nil)


        if let popoverPresentationController = tableViewController.popoverPresentationController {
            popoverPresentationController.barButtonItem = sender
        }
    }
    
    public func getValueForFacet(facet: Int) -> Int? {
        // TODO: remove this function
        return nil
    }
    
    public func setValueForFacet(facet: Int, value: Int?) {
//        if (!isFeedInitialized) {
//            return
//        }
        if let facetValue = value, let hrefValue = self.feed!.facets[facet].links[facetValue].href {
            // hrefValue is only a path, it doesn't have a scheme or domain name.
            // We get those from the original url
            let scheme = originalFeedURL?.scheme ?? "http"
            let host = originalFeedURL?.host ?? "unknown"
            let newURLString = scheme + "://" + host + hrefValue
            if let newURL = URL(string: newURLString) {
                loadNewURL(url: newURL)
            }
        }
        else {
            if let originalURL = originalFeedURL {
                loadNewURL(url: originalURL) // Note: this fails for multiple facet groups. Figure out a fix when an example is available
            }
        }
    }
    
    func loadNewURL(url: URL) {
        let opdsStoryboard = UIStoryboard(name: "OPDS", bundle: nil)
        let opdsRootViewController = opdsStoryboard.instantiateViewController(withIdentifier: "opdsRootViewController") as? OPDSRootTableViewController
        if let opdsRootViewController = opdsRootViewController {
            opdsRootViewController.originalFeedURL = url
            navigationController?.pushViewController(opdsRootViewController, animated: true)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        var numberOfSections = 0
        
        switch browsingState {
            
        case .Navigation, .Publication:
            numberOfSections = 1
            
        case .MixedGroup:
            numberOfSections = feed!.groups.count
            
        case .MixedNavigationPublication:
            numberOfSections = 2
            
        case .MixedNavigationGroupPublication:
            numberOfSections = 1 + feed!.groups.count + 1
            
        default:
            numberOfSections = 0
            
        }
        
        return numberOfSections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numberOfRowsInSection = 0
        
        switch browsingState {
            
        case .Navigation:
            numberOfRowsInSection = feed!.navigation.count
            
        case .Publication, .MixedGroup:
            numberOfRowsInSection = 1
            
        case .MixedNavigationPublication:
            if section == 0 {
                numberOfRowsInSection = feed!.navigation.count
            }
            if section == 1 {
                numberOfRowsInSection = 1
            }
            
        case .MixedNavigationGroupPublication:
            if section == 0 {
                numberOfRowsInSection = feed!.navigation.count
            }
            if section == 1 && section <= feed!.groups.count {
                numberOfRowsInSection = 1
            }
            if section == (feed!.groups.count + 1) {
                numberOfRowsInSection = 1
            }
            
        default:
            numberOfRowsInSection = 0
            
        }
        
        return numberOfRowsInSection
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var heightForRowAt: CGFloat = 0.0
        
        switch browsingState {
            
        case .Publication:
            heightForRowAt = tableView.bounds.height
            
        case .MixedGroup:
            heightForRowAt = 150
            
        default:
            heightForRowAt = 44
            
        }
        
        return heightForRowAt
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var title: String?

        switch browsingState {
            
        case .MixedGroup:
            if section >= 0 && section <= feed!.groups.count {
                title = feed!.groups[section].metadata.title
            }
        case .MixedNavigationGroupPublication:
            if section >= 1 && section <= (feed!.groups.count + 1) {
                title = feed!.groups[section-1].metadata.title
            }

        default:
            title = nil

        }

        return title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        
        switch browsingState {
            
        case .Navigation:
            let castedCell = tableView.dequeueReusableCell(withIdentifier: "opdsNavigationCell", for: indexPath) as! OPDSNavigationTableViewCell
            castedCell.title.text = feed?.navigation[indexPath.row].title
            if let count = feed?.navigation[indexPath.row].properties.numberOfItems {
                castedCell.count.text = "\(count)"
            } else {
                castedCell.count.text = ""
            }
            cell = castedCell
            
        case .Publication:
            let castedCell = tableView.dequeueReusableCell(withIdentifier: "opdsPublicationCell", for: indexPath) as! OPDSPublicationTableViewCell
            castedCell.feed = feed
            castedCell.opdsRootTableViewController = self
            cell = castedCell
            
        case .MixedGroup:
            let castedCell = tableView.dequeueReusableCell(withIdentifier: "opdsGroupCell", for: indexPath) as! OPDSGroupTableViewCell
            castedCell.group = feed?.groups[indexPath.section]
            castedCell.opdsRootTableViewController = self
            cell = castedCell

        default:
            cell = tableView.dequeueReusableCell(withIdentifier: "opdsNavigationCell", for: indexPath)
            cell?.contentView.backgroundColor = UIColor.orange
            
        }
        
        return cell!
    }
    
    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch browsingState {
            
        case .Navigation:
            if let href = feed?.navigation[indexPath.row].href {
                let opdsStoryboard = UIStoryboard(name: "OPDS", bundle: nil)
                let opdsRootViewController = opdsStoryboard.instantiateViewController(withIdentifier: "opdsRootViewController") as? OPDSRootTableViewController
                if let opdsRootViewController = opdsRootViewController {
                    opdsRootViewController.originalFeedURL = URL(string: href)
                    navigationController?.pushViewController(opdsRootViewController, animated: true)
                }
            }
            
        default:
            break
            
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.boldSystemFont(ofSize: 13)
        
        if view.subviews.last is UIButton {
            return
        }

        let buttonWidth: CGFloat = 70
        let moreButton = OPDSMoreButton(type: .system)
        moreButton.frame = CGRect(x: header.frame.width - buttonWidth, y: 0, width: buttonWidth, height: header.frame.height)
        
        moreButton.setTitle("more >", for: .normal)
        moreButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 11)
        moreButton.setTitleColor(UIColor.darkGray, for: .normal)
        
        moreButton.section = section
        
        moreButton.addTarget(self, action: #selector(moreAction), for: .touchUpInside)
        
        view.addSubview(moreButton)
        
        moreButton.translatesAutoresizingMaskIntoConstraints = false
        moreButton.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
        moreButton.heightAnchor.constraint(equalToConstant: header.frame.height).isActive = true
        moreButton.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    }
    
    //MARK: - Target action
    
    func moreAction(sender: UIButton!) {
        if let moreButton = sender as? OPDSMoreButton {
            if let links = feed?.groups[moreButton.section!].links {
                if links.count > 0 {
                    let opdsStoryboard = UIStoryboard(name: "OPDS", bundle: nil)
                    let opdsRootViewController = opdsStoryboard.instantiateViewController(withIdentifier: "opdsRootViewController") as? OPDSRootTableViewController
                    if let opdsRootViewController = opdsRootViewController {
                        opdsRootViewController.originalFeedURL = URL(string: links[0].href!)
                        navigationController?.pushViewController(opdsRootViewController, animated: true)
                    }
                }
            }
        }
    }

}

class OPDSMoreButton: UIButton {
    var section: Int?
}
