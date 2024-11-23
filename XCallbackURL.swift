import UIKit
import Foundation

enum XCallbackURLError: Error {
    case couldNotCreateURL
    case bundleURLTypesNotFound
    case mutlipleURLTypes
    case bundleURLSchemesNotFound
    case multipleURLSchemes
}

enum HandleURLError: Error {
    case invalidURL
    case noHost
    case unknownCommandInHost
    case noRequestID
    case unrecognisedRequestID
}

enum CallbackError: Error {
    case unknown
}

private let requestIDQueryKey = "requestID" 

private enum URLCommand: String {
    case successCallback
    case cancellationCallback
    case failureCallback
}

// An implementation of [x-callback-url](https://x-callback-url.com/) using Swift async await.
@MainActor final class XCallbackURLHandler {
    static let shared = XCallbackURLHandler()
    private init() {}
    private var activeRequests: [String: CheckedContinuation<Void, Error>] = [:]

    func openXCallbackURL(scheme: String, path: String, queryItems: [URLQueryItem] = []) async throws {
        // Examples:
        // working-copy://x-callback-url/<command>/?x-success=<escaped-url>&repo=...&key=...
        // shortcuts://x-callback-url/run-shortcut?name=Calculate%20Tip&input=text&text=24.99&x-success=...&x-cancel=...
        
        let callbackScheme = try Self.detectedURLScheme()
        let requestID = UUID().uuidString
        
        var successURLComponents = URLComponents()
        successURLComponents.scheme = callbackScheme
        successURLComponents.host = URLCommand.successCallback.rawValue
        successURLComponents.queryItems = [
            URLQueryItem(name: requestIDQueryKey, value: requestID)
        ]
        
        var urlComponents = URLComponents()
        urlComponents.scheme = scheme
        urlComponents.host = "x-callback-url"
        urlComponents.path = path
        var allQueryItems = queryItems
        if let thisAppName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String {
            allQueryItems.append(URLQueryItem(name: "x-source", value: thisAppName))
        }
        allQueryItems.append(contentsOf: [
            URLQueryItem(name: "x-success", value: successURLComponents.url!.absoluteString),
            URLQueryItem(name: "x-cancel", value: ""),
            URLQueryItem(name: "x-error", value: ""),
        ])
        urlComponents.queryItems = allQueryItems
        
        guard let xCallbackURL = urlComponents.url else {
            throw XCallbackURLError.couldNotCreateURL
        }
        print("Created x-callback-url: \(xCallbackURL)")
        try await withCheckedThrowingContinuation { continuation in
            activeRequests[requestID] = continuation
            UIApplication.shared.open(xCallbackURL)
        }
    }
    
    // Tries to handle a URL that was opened in this app.
    func handleURL(_ receivedURL: URL) throws {
        print("Handling \(receivedURL)")
        guard let components = URLComponents(url: receivedURL, resolvingAgainstBaseURL: false) else {
            throw HandleURLError.invalidURL 
        }
        guard let host = components.host else {
            throw HandleURLError.noHost
        }
        guard let command = URLCommand(rawValue: host) else {
            throw HandleURLError.unknownCommandInHost
        }
        let requestIDQueryItem = (components.queryItems ?? []).first {
            $0.name == requestIDQueryKey
        }
        guard let requestIDQueryItem, let requestID = requestIDQueryItem.value else {
            throw HandleURLError.noRequestID
        }
        guard let activeRequest = activeRequests[requestID] else {
            // TODO: This will happen if this app is terminated in the background while the other app is running. Not sure how to handle this. 
            throw HandleURLError.unrecognisedRequestID
        }
        
        activeRequests[requestID] = nil
        switch command {
        case .successCallback:
            activeRequest.resume()
        case .failureCallback:
            // TODO: Parse errorCode and errorMessage from query params
            activeRequest.resume(throwing: CallbackError.unknown)
        case .cancellationCallback:
            // TODO: Work out how cancellations should be done.
            fatalError()
        }
    }
    
    // A URL scheme that opens this app. This throws if app dosen’t declare exactly one URL scheme.
    static private func detectedURLScheme() throws -> String {
        guard let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else {
            throw XCallbackURLError.bundleURLTypesNotFound
        }
        guard urlTypes.count == 1 else {
            throw XCallbackURLError.mutlipleURLTypes
        }
        guard let urlSchemes = urlTypes[0]["CFBundleURLSchemes"] as? [String] else {
            throw XCallbackURLError.bundleURLSchemesNotFound
        }
        guard urlSchemes.count == 1 else {
            throw XCallbackURLError.multipleURLSchemes
        }
        return urlSchemes[0]
    }
}
