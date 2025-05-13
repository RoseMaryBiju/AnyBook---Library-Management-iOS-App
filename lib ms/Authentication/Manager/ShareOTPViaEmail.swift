
//
//  EmailJSManager.swift
//  LMSApp
//
//  Created by admin12 on 23/04/25.
//

import Foundation

class EmailJSManager {
    static let shared = EmailJSManager()
    
    /// Sends an OTP to the specified email address.
    /// - Parameters:
    ///   - email: The recipient's email address.
    ///   - otp: The OTP code to send.
    ///   - userName: The name of the user (optional, defaults to "User").
    ///   - completion: A closure that returns a Result indicating success or failure.
    func sendOTP(to email: String, otp: String, userName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Validate email format
        guard isValidEmail(email) else {
            let error = NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid email address"])
            completion(.failure(error))
            return
        }
        
        let url = URL(string: "https://api.emailjs.com/api/v1.0/email/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // Handle slow networks
        
        // EmailJS payload for OTP
        let payload: [String: Any] = [
            "user_id": "jIGWkpKnWSzEQEV3W",
            "service_id": "service_b941w6y",
            "template_id": "template_yzwxgyk",
            "template_params": [
                "user_name": userName.isEmpty ? "User" : userName,
                "otp_code": otp,
                "to_email": email
            ]
        ]
        
        // Debug payload
        print("EmailJS Payload (OTP): \(payload)")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("JSON Serialization Error: \(error)")
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error as NSError? {
                let errorMessage: String
                switch error.code {
                case NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet:
                    errorMessage = "No internet connection. Please check your network."
                case NSURLErrorTimedOut:
                    errorMessage = "Request timed out. Please try again."
                case NSURLErrorBadServerResponse:
                    errorMessage = "Invalid server response. Please try again later."
                case NSURLErrorCannotConnectToHost:
                    errorMessage = "Cannot connect to EmailJS server. Please try again later."
                default:
                    errorMessage = "Failed to send OTP: \(error.localizedDescription)"
                }
                print("Network Error (OTP): \(errorMessage) (Code: \(error.code))")
                completion(.failure(NSError(domain: "", code: error.code, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No server response"])
                print("No HTTP Response (OTP)")
                completion(.failure(error))
                return
            }
            
            print("HTTP Status (OTP): \(httpResponse.statusCode)")
            
            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                let errorMessage: String
                switch httpResponse.statusCode {
                case 401:
                    errorMessage = "Invalid EmailJS credentials. Please contact support."
                case 429:
                    errorMessage = "EmailJS request limit reached. Please try again later."
                default:
                    errorMessage = "Server error: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                }
                print("Server Error (OTP): \(errorMessage) (Status: \(httpResponse.statusCode))")
                completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            }
        }
        
        task.resume()
    }
    
    /// Sends librarian credentials to the specified email address.
    /// - Parameters:
    ///   - email: The recipient's personal email address.
    ///   - userName: The name of the librarian (optional, defaults to "Librarian").
    ///   - generatedEmail: The generated email address for the librarian's account.
    ///   - password: The generated password for the librarian's account.
    ///   - completion: A closure that returns a Result indicating success or failure.
    func sendCredentials(to email: String, userName: String, generatedEmail: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Validate email format
        guard isValidEmail(email) else {
            let error = NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid email address"])
            completion(.failure(error))
            return
        }
        
        let url = URL(string: "https://api.emailjs.com/api/v1.0/email/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // Handle slow networks
        
        // EmailJS payload for credentials
        let payload: [String: Any] = [
            "user_id": "jIGWkpKnWSzEQEV3W",
            "service_id": "service_b941w6y",
            "template_id": "template_qadjevr", // Replace with your actual template ID for credentials
            "template_params": [
                "user_name": userName.isEmpty ? "Librarian" : userName,
                "generated_email": generatedEmail,
                "password": password,
                "to_email": email
            ]
        ]
        
        // Debug payload
        print("EmailJS Payload (Credentials): \(payload)")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("JSON Serialization Error: \(error)")
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error as NSError? {
                let errorMessage: String
                switch error.code {
                case NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet:
                    errorMessage = "No internet connection. Please check your network."
                case NSURLErrorTimedOut:
                    errorMessage = "Request timed out. Please try again."
                case NSURLErrorBadServerResponse:
                    errorMessage = "Invalid server response. Please try again later."
                case NSURLErrorCannotConnectToHost:
                    errorMessage = "Cannot connect to EmailJS server. Please try again later."
                default:
                    errorMessage = "Failed to send credentials: \(error.localizedDescription)"
                }
                print("Network Error (Credentials): \(errorMessage) (Code: \(error.code))")
                completion(.failure(NSError(domain: "", code: error.code, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No server response"])
                print("No HTTP Response (Credentials)")
                completion(.failure(error))
                return
            }
            
            print("HTTP Status (Credentials): \(httpResponse.statusCode)")
            
            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                let errorMessage: String
                switch httpResponse.statusCode {
                case 401:
                    errorMessage = "Invalid EmailJS credentials. Please contact support."
                case 429:
                    errorMessage = "EmailJS request limit reached. Please try again later."
                default:
                    errorMessage = "Server error: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                }
                print("Server Error (Credentials): \(errorMessage) (Status: \(httpResponse.statusCode))")
                completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            }
        }
        
        task.resume()
    }
    
    /// Validates an email address using a regex pattern.
    /// - Parameter email: The email address to validate.
    /// - Returns: A Boolean indicating whether the email is valid.
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}
