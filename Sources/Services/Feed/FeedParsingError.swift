//
//  FeedParsingError.swift
//  JogPod
//
//  Created for JogPod Revival project.
//

import Foundation

// MARK: - Feed Parsing Error

/// Comprehensive error types for RSS/Atom feed parsing operations.
///
/// This enum covers all error scenarios that can occur during feed fetching
/// and parsing, from network failures to invalid XML and malformed feed data.
///
/// The error codes are aligned with the legacy MWFeedParser error codes
/// for easier migration and debugging.
public enum FeedParsingError: Error, LocalizedError, Equatable, Sendable {

    // MARK: - Configuration Errors

    /// The feed URL is invalid or malformed.
    case invalidURL(String)

    /// The feed parser was not properly initialized.
    case notInitialized(reason: String)

    // MARK: - Network Errors

    /// Network connection failed.
    case connectionFailed(underlying: String)

    /// The network request timed out.
    case timeout(seconds: TimeInterval)

    /// Server returned an HTTP error response.
    case httpError(statusCode: Int, message: String?)

    /// SSL/TLS certificate validation failed.
    case certificateError(underlying: String)

    // MARK: - Parsing Errors

    /// The XML document could not be parsed.
    case xmlParsingFailed(underlying: String)

    /// The XML document is not a valid RSS or Atom feed.
    case invalidFeedFormat(details: String)

    /// The feed validation failed.
    case feedValidationError(underlying: String)

    /// The feed encoding could not be determined or converted.
    case encodingError(encoding: String?)

    /// A required element was missing from the feed.
    case missingRequiredElement(elementName: String)

    // MARK: - Data Errors

    /// No data was received from the server.
    case noDataReceived

    /// The response data was empty.
    case emptyResponse

    /// Date parsing failed for a feed item.
    case dateParsingFailed(dateString: String)

    // MARK: - Operation Errors

    /// The parsing operation was cancelled.
    case cancelled

    /// The parsing operation is already in progress.
    case parsingInProgress

    /// A general/unknown error occurred.
    case general(message: String)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid feed URL: \(url)"

        case .notInitialized(let reason):
            return "Feed parser not initialized: \(reason)"

        case .connectionFailed(let underlying):
            return "Connection failed: \(underlying)"

        case .timeout(let seconds):
            return "Request timed out after \(Int(seconds)) seconds."

        case .httpError(let statusCode, let message):
            if let message = message {
                return "HTTP error \(statusCode): \(message)"
            }
            return "HTTP error \(statusCode)"

        case .certificateError(let underlying):
            return "Certificate validation failed: \(underlying)"

        case .xmlParsingFailed(let underlying):
            return "XML parsing failed: \(underlying)"

        case .invalidFeedFormat(let details):
            return "Invalid feed format: \(details)"

        case .feedValidationError(let underlying):
            return "Feed validation error: \(underlying)"

        case .encodingError(let encoding):
            if let encoding = encoding {
                return "Failed to decode feed with encoding: \(encoding)"
            }
            return "Failed to decode feed encoding."

        case .missingRequiredElement(let elementName):
            return "Missing required element: \(elementName)"

        case .noDataReceived:
            return "No data received from server."

        case .emptyResponse:
            return "Server returned an empty response."

        case .dateParsingFailed(let dateString):
            return "Failed to parse date: \(dateString)"

        case .cancelled:
            return "Feed parsing was cancelled."

        case .parsingInProgress:
            return "A parsing operation is already in progress."

        case .general(let message):
            return message
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Check the feed URL and ensure it is properly formatted."

        case .connectionFailed, .timeout:
            return "Check your internet connection and try again."

        case .httpError(let statusCode, _):
            if statusCode == 404 {
                return "The feed may have been moved or deleted."
            } else if statusCode >= 500 {
                return "The server is experiencing issues. Try again later."
            }
            return nil

        case .certificateError:
            return "The server's security certificate could not be verified."

        case .invalidFeedFormat, .xmlParsingFailed:
            return "The URL may not point to a valid RSS or Atom feed."

        case .encodingError:
            return "The feed may be using an unsupported character encoding."

        case .parsingInProgress:
            return "Wait for the current operation to complete."

        case .cancelled:
            return "Try refreshing the feed again."

        default:
            return nil
        }
    }

    public var failureReason: String? {
        switch self {
        case .connectionFailed:
            return "The network connection could not be established."

        case .timeout:
            return "The server took too long to respond."

        case .httpError(let statusCode, _):
            return "Server returned HTTP status \(statusCode)."

        case .invalidFeedFormat:
            return "The document is not a recognized feed format."

        case .xmlParsingFailed:
            return "The XML document contains errors."

        default:
            return nil
        }
    }

    // MARK: - Legacy Error Code Mapping

    /// Legacy error code for compatibility with MWFeedParser error handling.
    ///
    /// These codes match the original MWFeedParser error codes:
    /// - 1: Not initiated
    /// - 2: Connection failed
    /// - 3: Parsing error
    /// - 4: Validation error
    /// - 5: General error
    public var legacyErrorCode: Int {
        switch self {
        case .notInitialized, .invalidURL:
            return 1 // MWErrorCodeNotInitiated
        case .connectionFailed, .timeout, .httpError, .certificateError, .noDataReceived:
            return 2 // MWErrorCodeConnectionFailed
        case .xmlParsingFailed, .invalidFeedFormat, .encodingError, .missingRequiredElement, .dateParsingFailed:
            return 3 // MWErrorCodeFeedParsingError
        case .feedValidationError:
            return 4 // MWErrorCodeFeedValidationError
        case .emptyResponse, .cancelled, .parsingInProgress, .general:
            return 5 // MWErrorCodeGeneral
        }
    }

    /// The error domain for feed parsing errors.
    public static let errorDomain = "FeedParsingError"
}

// MARK: - Error Classification

extension FeedParsingError {

    /// Whether this error is potentially recoverable by retrying.
    public var isRetryable: Bool {
        switch self {
        case .connectionFailed, .timeout, .noDataReceived:
            return true
        case .httpError(let statusCode, _):
            // Retry on server errors (5xx) and some client errors
            return statusCode >= 500 || statusCode == 429 || statusCode == 408
        default:
            return false
        }
    }

    /// Whether this error is a network-related error.
    public var isNetworkError: Bool {
        switch self {
        case .connectionFailed, .timeout, .httpError, .certificateError, .noDataReceived:
            return true
        default:
            return false
        }
    }

    /// Whether this error indicates an invalid or malformed feed.
    public var isFeedError: Bool {
        switch self {
        case .invalidFeedFormat, .xmlParsingFailed, .feedValidationError,
             .encodingError, .missingRequiredElement:
            return true
        default:
            return false
        }
    }

    /// Whether this error was caused by user action (cancellation).
    public var isUserInitiated: Bool {
        switch self {
        case .cancelled:
            return true
        default:
            return false
        }
    }
}

// MARK: - NSError Bridge

extension FeedParsingError {

    /// Creates an NSError representation for Objective-C interoperability.
    public var nsError: NSError {
        NSError(
            domain: Self.errorDomain,
            code: legacyErrorCode,
            userInfo: [
                NSLocalizedDescriptionKey: errorDescription ?? "Unknown error",
                NSLocalizedFailureReasonErrorKey: failureReason ?? "",
                NSLocalizedRecoverySuggestionErrorKey: recoverySuggestion ?? ""
            ]
        )
    }
}
