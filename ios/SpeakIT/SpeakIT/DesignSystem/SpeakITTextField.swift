//
//  SpeakITTextField.swift
//  SpeakIT
//
//  Standard form text field matching 01_Login.svg.
//

import SwiftUI

struct SpeakITTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autoCapitalization: TextInputAutocapitalization = .never
    
    @State private var isPasswordVisible: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color.speakitTextTertiary)
            }
            
            if isSecure && !isPasswordVisible {
                SecureField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(Color.speakitTextPrimary)
                    .textInputAutocapitalization(autoCapitalization)
                    .keyboardType(keyboardType)
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(Color.speakitTextPrimary)
                    .textInputAutocapitalization(autoCapitalization)
                    .keyboardType(keyboardType)
            }
            
            if isSecure {
                Button(action: {
                    isPasswordVisible.toggle()
                }) {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.speakitTextTertiary)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: SpeakITSpacing.inputHeight)
        .background(Color.speakitBackground)
        .cornerRadius(SpeakITSpacing.inputRadius)
        .overlay(
            RoundedRectangle(cornerRadius: SpeakITSpacing.inputRadius)
                .stroke(Color.speakitBorder, lineWidth: 1)
        )
    }
}
