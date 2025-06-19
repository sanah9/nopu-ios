//
//  DatabaseManager.swift
//  nopu
//
//  Created by assistant on 2025/6/10.
//

import Foundation
import CoreData

@MainActor
class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "SubscriptionDataModel")
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                // More detailed error handling can be added here
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - Subscription CRUD Operations
    
    func fetchSubscriptions() -> [SubscriptionEntity] {
        let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SubscriptionEntity.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Fetch error: \(error)")
            return []
        }
    }
    
    func addSubscription(_ subscription: Subscription) {
        let entity = SubscriptionEntity(context: context)
        entity.id = subscription.id
        entity.topicName = subscription.topicName
        entity.groupId = subscription.groupId
        entity.createdAt = subscription.createdAt
        entity.lastNotificationAt = subscription.lastNotificationAt
        entity.unreadCount = Int32(subscription.unreadCount)
        entity.latestMessage = subscription.latestMessage
        entity.isActive = subscription.isActive
        entity.serverURL = subscription.serverURL
        
        // Serialize filters to JSON string
        if let filtersData = try? JSONEncoder().encode(subscription.filters),
           let filtersString = String(data: filtersData, encoding: .utf8) {
            entity.filtersData = filtersString
        } else {
            entity.filtersData = nil
        }
        
        // Add notifications
        for notification in subscription.notifications {
            let notificationEntity = NotificationEntity(context: context)
            notificationEntity.id = notification.id
            notificationEntity.message = notification.message
            notificationEntity.receivedAt = notification.receivedAt
            notificationEntity.isRead = notification.isRead
            notificationEntity.type = notification.type.rawValue
            notificationEntity.eventJSON = notification.eventJSON
            notificationEntity.relayURL = notification.relayURL
            notificationEntity.authorPubkey = notification.authorPubkey
            notificationEntity.eventId = notification.eventId
            notificationEntity.eventKind = notification.eventKind != nil ? Int32(notification.eventKind!) : 0
            notificationEntity.eventCreatedAt = notification.eventCreatedAt
            notificationEntity.subscription = entity
        }
        
        save()
    }
    
    func updateSubscription(_ subscription: Subscription) {
        let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", subscription.id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.topicName = subscription.topicName
                entity.groupId = subscription.groupId
                entity.lastNotificationAt = subscription.lastNotificationAt
                entity.unreadCount = Int32(subscription.unreadCount)
                entity.latestMessage = subscription.latestMessage
                entity.isActive = subscription.isActive
                entity.serverURL = subscription.serverURL
                
                // Update serialized filters
                if let filtersData = try? JSONEncoder().encode(subscription.filters),
                   let filtersString = String(data: filtersData, encoding: .utf8) {
                    entity.filtersData = filtersString
                } else {
                    entity.filtersData = nil
                }
                
                // Delete old notifications
                if let notifications = entity.notifications {
                    for notification in notifications {
                        context.delete(notification as! NSManagedObject)
                    }
                }
                
                // Add new notifications
                for notification in subscription.notifications {
                    let notificationEntity = NotificationEntity(context: context)
                    notificationEntity.id = notification.id
                    notificationEntity.message = notification.message
                    notificationEntity.receivedAt = notification.receivedAt
                    notificationEntity.isRead = notification.isRead
                    notificationEntity.type = notification.type.rawValue
                    notificationEntity.eventJSON = notification.eventJSON
                    notificationEntity.relayURL = notification.relayURL
                    notificationEntity.authorPubkey = notification.authorPubkey
                    notificationEntity.eventId = notification.eventId
                    notificationEntity.eventKind = notification.eventKind != nil ? Int32(notification.eventKind!) : 0
                    notificationEntity.eventCreatedAt = notification.eventCreatedAt
                    notificationEntity.subscription = entity
                }
                
                save()
            }
        } catch {
            print("Update error: \(error)")
        }
    }
    
    func deleteSubscription(id: UUID) {
        let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            save()
        } catch {
            print("Delete error: \(error)")
        }
    }
    
    func markSubscriptionAsRead(id: UUID) {
        let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.unreadCount = 0
                
                // Mark all notifications as read
                if let notifications = entity.notifications {
                    for notification in notifications {
                        (notification as! NotificationEntity).isRead = true
                    }
                }
                
                save()
            }
        } catch {
            print("Mark as read error: \(error)")
        }
    }
    
    func addNotificationToSubscription(topicName: String, message: String, type: NotificationType = .general) {
        let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "topicName == %@", topicName)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                let notificationEntity = NotificationEntity(context: context)
                notificationEntity.id = UUID()
                notificationEntity.message = message
                notificationEntity.receivedAt = Date()
                notificationEntity.isRead = false
                notificationEntity.type = type.rawValue
                notificationEntity.subscription = entity
                
                entity.unreadCount += 1
                entity.latestMessage = message
                entity.lastNotificationAt = Date()
                
                // Limit notification history count
                if let notifications = entity.notifications?.allObjects as? [NotificationEntity] {
                    if notifications.count > 100 {
                        let sortedNotifications = notifications.sorted { $0.receivedAt! > $1.receivedAt! }
                        for i in 100..<sortedNotifications.count {
                            context.delete(sortedNotifications[i])
                        }
                    }
                }
                
                save()
            }
        } catch {
            print("Add notification error: \(error)")
        }
    }
    
    /// Append a detailed NotificationItem to a subscription by id, avoiding expensive full updates
    func appendNotification(subscriptionId: UUID, notification: NotificationItem) {
        let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", subscriptionId as CVarArg)

        do {
            guard let entity = try context.fetch(request).first else { return }

            let notificationEntity = NotificationEntity(context: context)
            notificationEntity.id = notification.id
            notificationEntity.message = notification.message
            notificationEntity.receivedAt = notification.receivedAt
            notificationEntity.isRead = notification.isRead
            notificationEntity.type = notification.type.rawValue
            notificationEntity.eventJSON = notification.eventJSON
            notificationEntity.relayURL = notification.relayURL
            notificationEntity.authorPubkey = notification.authorPubkey
            notificationEntity.eventId = notification.eventId
            if let kind = notification.eventKind { notificationEntity.eventKind = Int32(kind) }
            notificationEntity.eventCreatedAt = notification.eventCreatedAt
            notificationEntity.subscription = entity

            // Update summary fields
            entity.unreadCount += 1
            entity.latestMessage = notification.message
            entity.lastNotificationAt = Date()

            // Keep only newest 100 notifications
            if let allNotifs = entity.notifications?.allObjects as? [NotificationEntity], allNotifs.count > 100 {
                let sorted = allNotifs.sorted { ($0.receivedAt ?? Date()) > ($1.receivedAt ?? Date()) }
                for old in sorted.dropFirst(100) { context.delete(old) }
            }

            save()
        } catch {
            print("appendNotification error: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    
    func convertToSubscription(_ entity: SubscriptionEntity) -> Subscription {
        // Convert notifications
        var notifications: [NotificationItem] = []
        if let notificationEntities = entity.notifications?.allObjects as? [NotificationEntity] {
            notifications = notificationEntities.sorted { $0.receivedAt! > $1.receivedAt! }.compactMap { notificationEntity in
                return NotificationItem(
                    id: notificationEntity.id ?? UUID(),
                    message: notificationEntity.message ?? "",
                    receivedAt: notificationEntity.receivedAt ?? Date(),
                    isRead: notificationEntity.isRead,
                    type: NotificationType(rawValue: notificationEntity.type ?? "general") ?? .general,
                    eventJSON: notificationEntity.eventJSON,
                    relayURL: notificationEntity.relayURL,
                    authorPubkey: notificationEntity.authorPubkey,
                    eventId: notificationEntity.eventId,
                    eventKind: notificationEntity.eventKind != 0 ? Int(notificationEntity.eventKind) : nil,
                    eventCreatedAt: notificationEntity.eventCreatedAt
                )
            }
        }
        
        // Deserialize filters
        var filters = NostrFilterConfig()
        if let filtersString = entity.filtersData,
           let filtersData = filtersString.data(using: .utf8),
           let decodedFilters = try? JSONDecoder().decode(NostrFilterConfig.self, from: filtersData) {
            filters = decodedFilters
        }
        
        return Subscription(
            id: entity.id ?? UUID(),
            topicName: entity.topicName ?? "",
            groupId: entity.groupId ?? "",
            createdAt: entity.createdAt ?? Date(),
            lastNotificationAt: entity.lastNotificationAt,
            unreadCount: Int(entity.unreadCount),
            latestMessage: entity.latestMessage,
            isActive: entity.isActive,
            serverURL: entity.serverURL ?? "",
            notifications: notifications,
            filters: filters
        )
    }
} 