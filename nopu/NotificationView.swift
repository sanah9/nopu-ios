//
//  NotificationView.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

struct NotificationView: View {
    @Binding var showingAddSubscription: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Empty state view
                VStack(spacing: 24) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Text("It looks like you don't have any subscriptions yet")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        VStack(spacing: 8) {
                            Text("Click the + to create or subscribe to a topic")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Subscribed topics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddSubscription = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
} 