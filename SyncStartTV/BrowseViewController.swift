/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 ViewController for the Bonjour browser view
 */

import UIKit
import AVFoundation

/// This is a viewController for a generic Bonjour service browser that browses for HTTP service advertisements
class BrowseViewController: UIViewController, NetServiceBrowserDelegate, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var serviceTable: UITableView?
    
    var browser: NetServiceBrowser
    var services: [NetService]
    public var selectedService: NetService?
    
    required init?(coder: NSCoder) {
        browser = NetServiceBrowser()
        services = []
        selectedService = nil
        super.init(coder: coder)
        browser.delegate = self
    }
    
    deinit {
        browser.stop()
        browser.delegate = nil
        if let serviceTable = serviceTable {
            serviceTable.delegate = nil
            serviceTable.dataSource = nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let serviceTable = serviceTable {
            serviceTable.delegate = self
            serviceTable.dataSource = self
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        selectedService = nil
        browser.searchForServices(ofType: "_http._tcp", inDomain: "")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        browser.stop()
        services.removeAll()
        super.viewDidDisappear(animated)
    }
    
    func serviceIndexFor(service: NetService) -> Int? {
        for servIndex in 0..<services.count where service.name == services[servIndex].name {
            return servIndex
        }
        return nil
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        let servIndex = serviceIndexFor(service: service)
        if servIndex == nil {
            services.append(service)
            let paths = [IndexPath(row: services.count - 1, section: 0)]
            serviceTable?.insertRows(at: paths, with: .automatic)
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        if let servIndex = serviceIndexFor(service: service) {
            services.remove(at: servIndex)
            let paths = [IndexPath(row: servIndex, section: 0)]
            serviceTable?.deleteRows(at: paths, with: .automatic)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return services.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let servIndex = indexPath[1]
        let service = services[servIndex]
        
        let cell: UITableViewCell
        if let dequeuedCell = tableView.dequeueReusableCell(withIdentifier: service.name) {
            cell = dequeuedCell
        } else {
            cell = UITableViewCell(style: .default, reuseIdentifier: service.name)
        }
        
        cell.textLabel?.text = service.name
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedService = services[indexPath.row]
        performSegue(withIdentifier: "unwindToMain", sender: self)
    }
}

