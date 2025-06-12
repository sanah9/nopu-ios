//
//  SharedUIComponents.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

// MARK: - Shared UI Components

struct NotificationToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: $isOn)
                .fixedSize()
        }
    }
}

struct FilterItemRow: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Button("Remove") {
                onRemove()
            }
            .foregroundColor(.red)
            .font(.caption)
            .buttonStyle(BorderlessButtonStyle())
        }
    }
}

struct AddItemRow: View {
    let placeholder: String
    @Binding var text: String
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .disableAutocorrection(true)
            Button("Add") {
                onAdd()
            }
            .disabled(text.isEmpty)
        }
    }
}

struct TagFilterView: View {
    let tag: SubscriptionViewModel.TagFilter
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("#\(tag.key)")
                    .font(.headline)
                Spacer()
                Button("Remove tag") {
                    onRemove()
                }
                .foregroundColor(.red)
                .font(.caption)
                .buttonStyle(BorderlessButtonStyle())
            }
            
            ForEach(tag.values, id: \.self) { value in
                Text("  • \(value)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
} 