import SwiftUI
import ClassFlowCore

struct WeekSchedulePageView: View {
    let page: WeekSchedulePageModel
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onCurrent: () -> Void
    let onPendingDay: (DayScheduleSnapshot) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedCourse: CourseOccurrence?
    @State private var selectedDay: DayScheduleSnapshot?
    @State private var prefersAgenda = false

    private var requiresAgenda: Bool {
        dynamicType.isAccessibilitySize || page.layoutItems.contains { $0.width < Double(AppSpacing.touchTarget) }
    }

    var body: some View {
        VStack(spacing: 0) {
            WeekNavigationHeader(page: page, onPrevious: onPrevious, onNext: onNext,
                onCurrent: onCurrent)
            Divider()
            if page.timeSlots.isEmpty {
                AppEmptyState(title: "尚未设置作息时间",
                    message: "添加节次时间后，课程会显示在周课表网格中。", symbol: "clock")
            } else if requiresAgenda || prefersAgenda {
                WeekAccessibleAgenda(page: page, onCourse: { selectedCourse = $0 }, onDay: { day in
                    if day.dayStatus == .needsConfirmation { onPendingDay(day) }
                    else { selectedDay = day }
                })
            } else {
                ScrollView(.vertical) {
                    ScrollView(.horizontal) {
                        VStack(spacing: 0) {
                            WeekdayHeaderRow(page: page) { day in
                                if day.dayStatus == .needsConfirmation { onPendingDay(day) }
                                else { selectedDay = day }
                            }
                            WeekScheduleGrid(page: page) { selectedCourse = $0 }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.xl)
                        .id(page.snapshot.weekNumber)
                        .transition(.opacity)
                    }
                    .scrollIndicators(.visible)
                }
            }
        }
        .animation(reduceMotion ? nil : AppMotion.content(reduceMotion: false), value: page.snapshot.weekNumber)
        .toolbar {
            if !requiresAgenda {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { prefersAgenda.toggle() } label: {
                        Image(systemName: prefersAgenda ? "rectangle.split.3x3" : "list.bullet")
                            .frame(minWidth: AppSpacing.touchTarget, minHeight: AppSpacing.touchTarget)
                    }
                    .buttonStyle(AppPressStyle())
                    .accessibilityLabel(prefersAgenda ? "显示网格课表" : "显示完整课程列表")
                }
            }
        }
        .sheet(item: $selectedCourse) { course in
            CourseDetailSheet(course: course, timeZoneID: page.timeZoneID).appSheet()
        }
        .sheet(item: $selectedDay) { day in
            DayScheduleDetailSheet(day: day).appSheet()
        }
    }
}

private struct WeekNavigationHeader: View {
    let page: WeekSchedulePageModel
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onCurrent: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.md) { heading; controls }
            VStack(alignment: .leading, spacing: AppSpacing.md) { heading; controls }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("第 \(page.snapshot.weekNumber) 教学周")
                .font(AppTypography.sectionTitle)
            Text(WeekScheduleDisplayText.dateRange(page.snapshot))
                .font(AppTypography.secondary)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        HStack(spacing: AppSpacing.sm) {
            Button(action: onPrevious) { Image(systemName: "chevron.left") }
                .disabled(page.snapshot.weekNumber <= 1)
                .accessibilityLabel("上一周")
            if page.snapshot.weekNumber != page.todayTargetWeek {
                Button("本周", action: onCurrent).font(AppTypography.secondary.weight(.semibold))
            }
            Button(action: onNext) { Image(systemName: "chevron.right") }
                .disabled(page.snapshot.weekNumber >= page.totalWeeks)
                .accessibilityLabel("下一周")
        }
        .buttonStyle(AppButtonStyle(.icon))
    }
}

private struct WeekdayHeaderRow: View {
    let page: WeekSchedulePageModel
    let onSelect: (DayScheduleSnapshot) -> Void
    @ScaledMetric(relativeTo: .body) private var headerHeight = WeekScheduleStyle.headerHeight

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: WeekScheduleStyle.timeColumnWidth,
                              height: headerHeight)
            ForEach(page.snapshot.days) { day in
                Button { onSelect(day) } label: {
                    VStack(spacing: AppSpacing.xs) {
                        Text(day.realWeekday.shortChineseName)
                            .font(AppTypography.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(day.date.month)/\(day.date.day)")
                            .font(AppTypography.secondary.weight(isToday(day) ? .semibold : .medium))
                            .foregroundStyle(isToday(day) ? AppColors.accent : Color.primary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(isToday(day) ? AppColors.accent.opacity(AppColors.tintOpacity) : Color.clear,
                                in: Capsule())
                        if let status = WeekScheduleDisplayText.compactStatus(day) {
                            AppTag(title: status, tint: day.dayStatus == .needsConfirmation
                                ? AppColors.warning : .secondary)
                        } else {
                            Text(" ").font(AppTypography.micro)
                        }
                    }
                    .frame(width: pageWidth)
                    .frame(minHeight: headerHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(AppPressStyle())
                .accessibilityLabel("\(day.realWeekday.chineseName)，\(day.date.month)月\(day.date.day)日，\(WeekScheduleDisplayText.detailStatus(day))")
            }
        }
    }

    private var pageWidth: CGFloat { CGFloat(WeekScheduleStyle.metrics.dayColumnWidth) }
    private func isToday(_ day: DayScheduleSnapshot) -> Bool { page.snapshot.currentDate == day.date }
}

private struct WeekScheduleGrid: View {
    let page: WeekSchedulePageModel
    let onSelectCourse: (CourseOccurrence) -> Void

    private var metrics: ScheduleLayoutMetrics { WeekScheduleStyle.metrics }
    private var gridHeight: CGFloat { CGFloat(Double(page.timeSlots.count) * metrics.sectionHeight) }
    private var daysWidth: CGFloat { CGFloat(Double(page.snapshot.days.count) * metrics.dayColumnWidth) }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            TimeSlotColumn(slots: page.timeSlots, metrics: metrics)
                .frame(width: WeekScheduleStyle.timeColumnWidth, height: gridHeight, alignment: .top)
            ZStack(alignment: .topLeading) {
                GridBackground(page: page, metrics: metrics)
                ForEach(page.layoutItems) { item in
                    Button { onSelectCourse(item.occurrence) } label: {
                        WeekCourseCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .frame(width: CGFloat(item.width), height: CGFloat(item.height))
                    .offset(x: CGFloat(Double(item.dayColumnIndex) * metrics.dayColumnWidth
                        + item.leadingOffset), y: CGFloat(item.topOffset))
                }
                if let offset = page.currentTimeOffset,
                   let todayIndex = page.snapshot.days.firstIndex(where: { $0.date == page.snapshot.currentDate }) {
                    CurrentTimeLine(width: CGFloat(metrics.dayColumnWidth))
                        .offset(x: CGFloat(Double(todayIndex) * metrics.dayColumnWidth), y: CGFloat(offset))
                }
            }
            .frame(width: daysWidth, height: gridHeight, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: WeekScheduleStyle.gridCornerRadius,
                                        style: .continuous))
        }
    }
}

private struct TimeSlotColumn: View {
    let slots: [TimeSlotDefinition]
    let metrics: ScheduleLayoutMetrics

    var body: some View {
        VStack(spacing: 0) {
            ForEach(slots, id: \.sectionNumber) { slot in
                VStack(spacing: AppSpacing.xs) {
                    Text("\(slot.sectionNumber)").font(AppTypography.secondary.weight(.semibold))
                    Text(WeekScheduleDisplayText.minute(slot.startMinute))
                        .font(AppTypography.micro.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.top, AppSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: CGFloat(metrics.sectionHeight),
                       maxHeight: CGFloat(metrics.sectionHeight), alignment: .top)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct GridBackground: View {
    let page: WeekSchedulePageModel
    let metrics: ScheduleLayoutMetrics

    var body: some View {
        ZStack(alignment: .topLeading) {
            AppColors.surface
            ForEach(Array(page.snapshot.days.enumerated()), id: \.offset) { index, day in
                dayBackground(day)
                    .frame(width: CGFloat(metrics.dayColumnWidth),
                           height: CGFloat(Double(page.timeSlots.count) * metrics.sectionHeight))
                    .offset(x: CGFloat(Double(index) * metrics.dayColumnWidth))
                if day.dayStatus == .holiday {
                    Label("放假", systemImage: "sun.max")
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: CGFloat(metrics.dayColumnWidth))
                        .offset(x: CGFloat(Double(index) * metrics.dayColumnWidth), y: 16)
                } else if day.dayStatus == .needsConfirmation {
                    Label("待确认", systemImage: "questionmark.circle")
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(AppColors.warning)
                        .frame(width: CGFloat(metrics.dayColumnWidth))
                        .offset(x: CGFloat(Double(index) * metrics.dayColumnWidth), y: 16)
                }
            }
            ForEach(0...page.timeSlots.count, id: \.self) { row in
                Rectangle()
                    .fill(AppColors.separator)
                    .frame(width: CGFloat(Double(page.snapshot.days.count) * metrics.dayColumnWidth),
                           height: AppSpacing.hairline)
                    .offset(y: CGFloat(Double(row) * metrics.sectionHeight))
            }
            ForEach(0...page.snapshot.days.count, id: \.self) { column in
                Rectangle()
                    .fill(Color(uiColor: .separator).opacity(0.28))
                    .frame(width: AppSpacing.hairline,
                           height: CGFloat(Double(page.timeSlots.count) * metrics.sectionHeight))
                    .offset(x: CGFloat(Double(column) * metrics.dayColumnWidth))
            }
        }
    }

    @ViewBuilder
    private func dayBackground(_ day: DayScheduleSnapshot) -> some View {
        switch day.dayStatus {
        case .holiday: Color.secondary.opacity(AppColors.subtleOpacity)
        case .needsConfirmation: AppColors.warning.opacity(AppColors.subtleOpacity)
        default: Color.clear
        }
    }
}

private struct CurrentTimeLine: View {
    let width: CGFloat
    var body: some View {
        HStack(spacing: 0) {
            Circle().fill(AppColors.accent).frame(width: AppSpacing.sm, height: AppSpacing.sm)
            Rectangle().fill(AppColors.accent).frame(height: AppSpacing.hairline)
        }
        .frame(width: width)
        .accessibilityHidden(true)
    }
}
