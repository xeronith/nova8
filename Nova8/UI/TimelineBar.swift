import SwiftUI

struct TimelineBar: View {
    @Environment(SimulatorModel.self) private var model

    private var allGroups: [HistoryGroup] {
        model.history.groups()
    }

    /// The recorder can hold thousands of cycles; render a window around the
    /// current cursor so the strip stays fast and the active chip stays visible.
    private var groups: [HistoryGroup] {
        let all = allGroups
        guard all.count > 60 else { return all }

        guard let current = currentEntryID,
              let index = all.firstIndex(where: { group in
                  group.entries.contains { $0.id == current }
              }) else {
            return Array(all.suffix(60))
        }

        let start = max(0, min(index - 30, all.count - 60))
        return Array(all[start..<(start + 60)])
    }

    private var currentEntryID: Int? {
        guard model.history.entries.indices.contains(model.history.cursor) else { return nil }
        return model.history.entries[model.history.cursor].id
    }

    var body: some View {
        Panel(
            title: "Flight recorder",
            meta: "\(model.history.entries.count - 1) cycles · \(allGroups.count) instructions",
            accessory: AnyView(trailing)
        ) {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 8) {
                            if groups.isEmpty {
                                emptyState
                            } else {
                                ForEach(groups) { group in
                                    groupView(group)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: .infinity)
                    .onAppear { scrollToCurrent(proxy, animated: false) }
                    .onChange(of: model.history.cursor) { _, _ in
                        scrollToCurrent(proxy, animated: true)
                    }
                    .onChange(of: groups.count) { _, _ in
                        scrollToCurrent(proxy, animated: true)
                    }

                    TimelineScrubber()
                }
            }
        }
    }

    private var trailing: some View {
        HStack(spacing: 8) {
            if !model.history.isLive {
                TinyChip(text: "REPLAY", color: Theme.amber)
                Button("Return to live") {
                    model.returnToLive()
                }
                .buttonStyle(.plain)
                .font(.ui(9, .medium))
                .foregroundStyle(Theme.cyan)
            } else {
                Text("click any chip to time-travel")
                    .font(.ui(8.5))
                    .foregroundStyle(Theme.faint)
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 7) {
            Image(systemName: "record.circle")
                .font(.system(size: 10))
                .foregroundStyle(Theme.faint)
            Text("Step the machine to begin recording cycles.")
                .font(.ui(9.5))
                .foregroundStyle(Theme.faint)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private func groupView(_ group: HistoryGroup) -> some View {
        let isCurrentGroup = group.entries.contains { $0.id == currentEntryID }

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(String(format: "%02X", group.address))
                    .font(.mono(7, .semibold))
                    .foregroundStyle(Theme.faint)
                Text(group.instructionText)
                    .font(.mono(8, .medium))
                    .foregroundStyle(isCurrentGroup ? Theme.text : Theme.dim)
                    .lineLimit(1)
            }

            HStack(spacing: 2) {
                ForEach(group.entries) { entry in
                    chip(entry)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Theme.inset.opacity(isCurrentGroup ? 0.85 : 0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(isCurrentGroup ? Theme.strokeStrong : Theme.stroke, lineWidth: 1)
        )
    }

    private func chip(_ entry: HistoryEntry) -> some View {
        let stage = entry.op?.stage
        let color = Theme.stage(stage)
        let isCurrent = entry.id == currentEntryID
        let isFuture = entry.id > (currentEntryID ?? Int.max)

        return Button {
            jump(to: entry)
        } label: {
            Text(entry.op?.slot ?? "·")
                .font(.mono(7, .semibold))
                .foregroundStyle(isCurrent ? Theme.background : color.opacity(isFuture ? 0.35 : 0.9))
                .frame(width: 20, height: 17)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isCurrent ? color : color.opacity(isFuture ? 0.04 : 0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(color.opacity(isCurrent ? 0 : 0.18), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .help("\(entry.op?.timelineTitle ?? "") — click to travel here")
        .id(entry.id)
    }

    private func jump(to entry: HistoryEntry) {
        guard let index = model.history.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        model.jumpHistory(to: index)
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let id = currentEntryID else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(id, anchor: .center)
            }
        } else {
            proxy.scrollTo(id, anchor: .center)
        }
    }
}

// MARK: - Scrubber

struct TimelineScrubber: View {
    @Environment(SimulatorModel.self) private var model

    var body: some View {
        let count = model.history.entries.count - 1
        let progress = count > 0 ? CGFloat(model.history.cursor) / CGFloat(count) : 0

        GeometryReader { geo in
            let width = max(1, geo.size.width)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.inset)
                    .frame(height: 6)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.cyan.opacity(0.65), Theme.violet.opacity(0.65)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, width * progress), height: 6)

                ForEach(instructionTicks, id: \.self) { tick in
                    Rectangle()
                        .fill(Theme.background.opacity(0.55))
                        .frame(width: 1, height: 6)
                        .offset(x: width * CGFloat(tick) / CGFloat(max(1, count)))
                }

                Circle()
                    .fill(Theme.cyan)
                    .frame(width: 9, height: 9)
                    .shadow(color: Theme.cyan.opacity(0.8), radius: 6)
                    .offset(x: width * progress - 4.5)
            }
            .frame(height: 14)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard count > 0 else { return }
                        let fraction = min(max(0, value.location.x / width), 1)
                        let index = Int((fraction * CGFloat(count)).rounded())
                        if index != model.history.cursor {
                            model.jumpHistory(to: index)
                        }
                    }
            )
        }
        .frame(height: 14)
        .padding(.horizontal, 12)
        .padding(.bottom, 5)
        .opacity(count > 0 ? 1 : 0.45)
    }

    private var instructionTicks: [Int] {
        let entries = model.history.entries
        guard entries.count > 2 else { return [] }
        var ticks: [Int] = []
        var lastSerial: Int?
        for (index, entry) in entries.enumerated() {
            guard let op = entry.op else { continue }
            if op.instructionSerial != lastSerial {
                ticks.append(index)
                lastSerial = op.instructionSerial
            }
        }
        return ticks
    }
}
