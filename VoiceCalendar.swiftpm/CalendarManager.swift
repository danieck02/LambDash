import EventKit
import SwiftUI

class CalendarManager: ObservableObject {
    private let store = EKEventStore()

    func requestAccess() {
        if #available(iOS 17.0, *) {
            store.requestWriteOnlyAccessToEvents { _, _ in }
        } else {
            store.requestAccess(to: .event) { _, _ in }
        }
    }

    func addEvent(_ parsed: ParsedEvent, completion: @escaping (Bool) -> Void) {
        let event = EKEvent(eventStore: store)
        event.title = parsed.title
        event.startDate = parsed.date
        event.endDate = parsed.date.addingTimeInterval(3600)
        event.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(event, span: .thisEvent)
            completion(true)
        } catch {
            completion(false)
        }
    }
}
