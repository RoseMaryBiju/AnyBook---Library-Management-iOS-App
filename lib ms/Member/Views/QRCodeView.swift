//
//  QRCodeView.swift
//  lib ms
//
//  Created by admin86 on 05/05/25.
//

import SwiftUI
import FirebaseAuth
import CoreImage

struct QRCodeView: View {
    @State private var uid: String? = nil
    @State private var qrCodeImage: UIImage? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            if let qrCodeImage = qrCodeImage {
                ZStack {
                    // QR Code Background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .frame(width: 200, height: 200)
                        .shadow(color: Color.black.opacity(0.1), radius: 10)
                    
                    // QR Code Image
                    Image(uiImage: qrCodeImage)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 180, height: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        )
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            }
            
            if let uid = uid {
                Text("Member ID: \(String(uid.prefix(8)))")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            fetchCurrentUserUID()
        }
    }
    
    private func fetchCurrentUserUID() {
        if let user = Auth.auth().currentUser {
            let uid = user.uid
            self.uid = uid
            generateQRCode(from: uid)
        }
    }
    
    private func generateQRCode(from string: String) {
        guard let data = string.data(using: .utf8) else { return }
        
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(data, forKey: "inputMessage")
        
        guard let outputImage = filter?.outputImage else { return }
        
        // Scale the QR code
        let scale = 10.0
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else { return }
        
        self.qrCodeImage = UIImage(cgImage: cgImage)
    }
}
