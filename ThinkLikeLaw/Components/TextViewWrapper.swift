import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/**
 * TextViewWrapper — A custom UITextView wrapper for SwiftUI.
 * Specifically used to disable the 'Paste' action for academic integrity.
 */
struct TextViewWrapper: View {
    let placeholder: String
    @Binding var text: String
    let isEditingEnabled: Bool
    #if canImport(UIKit)
    let font: UIFont
    #else
    let font: Font
    #endif
    
    var body: some View {
        #if canImport(UIKit)
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(Font(font))
                    .foregroundColor(Color(uiColor: .placeholderText))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
            }
            
            InternalUITextView(text: $text, isEditingEnabled: isEditingEnabled, font: font)
        }
        #else
        TextEditor(text: $text)
            .font(font)
            .disabled(!isEditingEnabled)
        #endif
    }
}

#if canImport(UIKit)
private struct InternalUITextView: UIViewRepresentable {
    @Binding var text: String
    let isEditingEnabled: Bool
    let font: UIFont
    
    func makeUIView(context: Context) -> CustomUITextView {
        let textView = CustomUITextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.backgroundColor = .clear
        textView.isEditable = isEditingEnabled
        textView.isScrollEnabled = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }
    
    func updateUIView(_ uiView: CustomUITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.isEditable = isEditingEnabled
        uiView.textColor = isEditingEnabled ? .label : .secondaryLabel
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: InternalUITextView
        
        init(_ parent: InternalUITextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

class CustomUITextView: UITextView {
    // Disable Paste for Academic Integrity
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UIResponderStandardEditActions.paste(_:)) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
}
#endif
