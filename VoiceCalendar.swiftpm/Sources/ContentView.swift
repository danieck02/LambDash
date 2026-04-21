import SwiftUI

struct ContentView: View {
    @StateObject private var speech = SpeechManager()
    @StateObject private var calendar = CalendarManager()
    @State private var feedback: String = ""
    @State private var feedbackIsSuccess = true

    var body: some View {
        VStack(spacing: 28) {
            Text("VoiceCalendar")
                .font(.largeTitle.bold())

            Picker("Taal", selection: $speech.locale) {
                Text("Nederlands").tag(Locale(identifier: "nl-NL"))
                Text("English").tag(Locale(identifier: "en-US"))
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            ScrollView {
                Text(speech.transcript.isEmpty
                     ? (speech.locale.identifier.hasPrefix("nl") ? "Druk op de knop en spreek..." : "Press the button and speak...")
                     : speech.transcript)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(height: 160)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Button {
                if speech.isRecording {
                    speech.stopRecording()
                    processTranscript()
                } else {
                    feedback = ""
                    speech.startRecording()
                }
            } label: {
                Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(speech.isRecording ? .red : .blue)
                    .symbolEffect(.bounce, value: speech.isRecording)
            }

            if !speech.errorMessage.isEmpty {
                Text(speech.errorMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
            } else if !feedback.isEmpty {
                Text(feedback)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(feedbackIsSuccess ? .green : .red)
                    .padding(.horizontal)
            }

            Spacer()

            Text(speech.locale.identifier.hasPrefix("nl")
                 ? "Zeg bijv: \"Vergadering morgen om 10 uur\""
                 : "Say e.g.: \"Meeting tomorrow at 10\"")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .onAppear {
            speech.requestPermissions()
            calendar.requestAccess()
        }
    }

    private func processTranscript() {
        let text = speech.transcript
        guard !text.isEmpty else { return }

        guard let event = EventParser.parse(text, locale: speech.locale) else {
            feedbackIsSuccess = false
            feedback = speech.locale.identifier.hasPrefix("nl")
                ? "Geen datum herkend. Probeer: \"Vergadering morgen om 10 uur\""
                : "No date found. Try: \"Meeting tomorrow at 10\""
            return
        }

        calendar.addEvent(event) { success in
            DispatchQueue.main.async {
                feedbackIsSuccess = success
                let dateStr = event.date.formatted(date: .long, time: .shortened)
                feedback = success
                    ? "✓ \(event.title) — \(dateStr)"
                    : "✗ Kon niet toevoegen aan agenda"
            }
        }
    }
}
