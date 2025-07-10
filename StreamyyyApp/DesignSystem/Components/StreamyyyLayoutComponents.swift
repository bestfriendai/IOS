//
//  StreamyyyLayoutComponents.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Layout components for consistent screen and section structure
//

import SwiftUI

// MARK: - StreamyyyScreenContainer
struct StreamyyyScreenContainer<Content: View>: View {
    let content: Content
    let backgroundColor: Color
    let padding: CGFloat
    let safeAreaAware: Bool
    
    init(
        backgroundColor: Color = StreamyyyColors.background,
        padding: CGFloat = StreamyyySpacing.screenPadding,
        safeAreaAware: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.backgroundColor = backgroundColor
        self.padding = padding
        self.safeAreaAware = safeAreaAware
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            content
                .padding(padding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .if(safeAreaAware) { view in
            view.safeAreaAwarePadding()
        }
    }
}

// MARK: - StreamyyySection
struct StreamyyySection<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content
    let spacing: CGFloat
    let titleStyle: StreamyyySectionTitleStyle
    
    init(
        title: String,
        subtitle: String? = nil,
        spacing: CGFloat = StreamyyySpacing.sectionSpacing,
        titleStyle: StreamyyySectionTitleStyle = .default,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.spacing = spacing
        self.titleStyle = titleStyle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            VStack(alignment: .leading, spacing: StreamyyySpacing.xs) {
                Text(title)
                    .font(titleFont)
                    .foregroundColor(titleColor)
                    .fontWeight(titleWeight)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .bodySmall()
                        .foregroundColor(StreamyyyColors.textSecondary)
                }
            }
            
            content
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
    }
    
    // MARK: - Computed Properties
    private var titleFont: Font {
        switch titleStyle {
        case .default:
            return StreamyyyTypography.titleLarge
        case .large:
            return StreamyyyTypography.headlineSmall
        case .small:
            return StreamyyyTypography.titleMedium
        case .display:
            return StreamyyyTypography.displaySmall
        }
    }
    
    private var titleColor: Color {
        switch titleStyle {
        case .default, .large, .small:
            return StreamyyyColors.textPrimary
        case .display:
            return StreamyyyColors.primary
        }
    }
    
    private var titleWeight: Font.Weight {
        switch titleStyle {
        case .default, .large, .small:
            return .semibold
        case .display:
            return .bold
        }
    }
}

// MARK: - StreamyyySectionTitleStyle
enum StreamyyySectionTitleStyle {
    case `default`
    case large
    case small
    case display
}

// MARK: - StreamyyyGrid
struct StreamyyyGrid<Content: View>: View {
    let content: Content
    let columns: Int
    let spacing: CGFloat
    let itemAspectRatio: CGFloat?
    
    init(
        columns: Int = 2,
        spacing: CGFloat = StreamyyySpacing.gridSpacing,
        itemAspectRatio: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.columns = columns
        self.spacing = spacing
        self.itemAspectRatio = itemAspectRatio
    }
    
    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            content
        }
    }
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }
}

// MARK: - StreamyyyList
struct StreamyyyList<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content
    let spacing: CGFloat
    let showSeparators: Bool
    
    init(
        _ data: Data,
        spacing: CGFloat = StreamyyySpacing.listSpacing,
        showSeparators: Bool = false,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.content = content
        self.spacing = spacing
        self.showSeparators = showSeparators
    }
    
    var body: some View {
        LazyVStack(spacing: spacing) {
            ForEach(data) { item in
                content(item)
                
                if showSeparators && item.id != data.last?.id {
                    Divider()
                        .background(StreamyyyColors.border)
                }
            }
        }
    }
}

// MARK: - StreamyyyScrollView
struct StreamyyyScrollView<Content: View>: View {
    let content: Content
    let axes: Axis.Set
    let showsIndicators: Bool
    let onRefresh: (() async -> Void)?
    
    init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        onRefresh: (() async -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content
        }
        .if(onRefresh != nil) { view in
            view.refreshable {
                await onRefresh?()
            }
        }
    }
}

// MARK: - StreamyyyTabView
struct StreamyyyTabView<Content: View>: View {
    let content: Content
    @Binding var selection: Int
    let tabStyle: StreamyyyTabStyle
    
    init(
        selection: Binding<Int>,
        tabStyle: StreamyyyTabStyle = .default,
        @ViewBuilder content: () -> Content
    ) {
        self._selection = selection
        self.tabStyle = tabStyle
        self.content = content()
    }
    
    var body: some View {
        TabView(selection: $selection) {
            content
        }
        .accentColor(accentColor)
        .onAppear {
            configureTabBarAppearance()
        }
    }
    
    private var accentColor: Color {
        switch tabStyle {
        case .default:
            return StreamyyyColors.primary
        case .accent:
            return StreamyyyColors.accent
        case .secondary:
            return StreamyyyColors.secondary
        }
    }
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(StreamyyyColors.surface)
        appearance.shadowColor = UIColor(StreamyyyColors.border)
        
        // Configure selected item appearance
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(accentColor)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(accentColor)
        ]
        
        // Configure normal item appearance
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(StreamyyyColors.textTertiary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(StreamyyyColors.textTertiary)
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - StreamyyyTabStyle
enum StreamyyyTabStyle {
    case `default`
    case accent
    case secondary
}

// MARK: - StreamyyyNavigationView
struct StreamyyyNavigationView<Content: View>: View {
    let content: Content
    let navigationStyle: StreamyyyNavigationStyle
    
    init(
        navigationStyle: StreamyyyNavigationStyle = .default,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.navigationStyle = navigationStyle
    }
    
    var body: some View {
        NavigationView {
            content
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            configureNavigationAppearance()
        }
    }
    
    private func configureNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(StreamyyyColors.background)
        appearance.shadowColor = UIColor(StreamyyyColors.border)
        
        // Configure title appearance
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(StreamyyyColors.textPrimary),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(StreamyyyColors.textPrimary),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        // Configure button appearance
        appearance.buttonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(StreamyyyColors.primary)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(StreamyyyColors.primary)
    }
}

// MARK: - StreamyyyNavigationStyle
enum StreamyyyNavigationStyle {
    case `default`
    case transparent
    case colored
}

// MARK: - StreamyyyDivider
struct StreamyyyDivider: View {
    let color: Color
    let thickness: CGFloat
    let padding: CGFloat
    
    init(
        color: Color = StreamyyyColors.border,
        thickness: CGFloat = StreamyyySpacing.separatorWidth,
        padding: CGFloat = 0
    ) {
        self.color = color
        self.thickness = thickness
        self.padding = padding
    }
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: thickness)
            .padding(.horizontal, padding)
    }
}

// MARK: - StreamyyySpacer
struct StreamyyySpacer: View {
    let size: StreamyyySpacerSize
    
    init(_ size: StreamyyySpacerSize = .medium) {
        self.size = size
    }
    
    var body: some View {
        Spacer()
            .frame(height: size.value)
    }
}

// MARK: - StreamyyySpacerSize
enum StreamyyySpacerSize {
    case extraSmall
    case small
    case medium
    case large
    case extraLarge
    case custom(CGFloat)
    
    var value: CGFloat {
        switch self {
        case .extraSmall: return StreamyyySpacing.xs
        case .small: return StreamyyySpacing.sm
        case .medium: return StreamyyySpacing.md
        case .large: return StreamyyySpacing.lg
        case .extraLarge: return StreamyyySpacing.xl
        case .custom(let value): return value
        }
    }
}

// MARK: - StreamyyyEmptyState
struct StreamyyyEmptyState: View {
    let title: String
    let subtitle: String?
    let icon: String
    let buttonTitle: String?
    let buttonAction: (() -> Void)?
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String = "tray",
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
    }
    
    var body: some View {
        VStack(spacing: StreamyyySpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 60, weight: .light))
                .foregroundColor(StreamyyyColors.textTertiary)
            
            VStack(spacing: StreamyyySpacing.sm) {
                Text(title)
                    .titleLarge()
                    .foregroundColor(StreamyyyColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .bodyMedium()
                        .foregroundColor(StreamyyyColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if let buttonTitle = buttonTitle, let buttonAction = buttonAction {
                StreamyyyButton(
                    title: buttonTitle,
                    style: .primary,
                    action: buttonAction
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(StreamyyySpacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
    }
}

// MARK: - StreamyyyLoadingView
struct StreamyyyLoadingView: View {
    let title: String?
    let style: StreamyyyLoadingStyle
    
    init(
        title: String? = nil,
        style: StreamyyyLoadingStyle = .default
    ) {
        self.title = title
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: StreamyyySpacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: tintColor))
                .scaleEffect(scale)
            
            if let title = title {
                Text(title)
                    .bodyMedium()
                    .foregroundColor(StreamyyyColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(StreamyyySpacing.xl)
        .accessibilityLabel("Loading")
        .accessibilityHint(title ?? "Please wait")
    }
    
    private var tintColor: Color {
        switch style {
        case .default:
            return StreamyyyColors.primary
        case .accent:
            return StreamyyyColors.accent
        case .secondary:
            return StreamyyyColors.secondary
        }
    }
    
    private var scale: CGFloat {
        switch style {
        case .default:
            return 1.0
        case .accent:
            return 1.2
        case .secondary:
            return 0.8
        }
    }
}

// MARK: - StreamyyyLoadingStyle
enum StreamyyyLoadingStyle {
    case `default`
    case accent
    case secondary
}

// MARK: - View Extension for Conditional Modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Layout Components Preview
struct StreamyyyLayoutComponentsPreview: View {
    @State private var selectedTab = 0
    
    var body: some View {
        StreamyyyTabView(selection: $selectedTab) {
            StreamyyyNavigationView {
                StreamyyyScreenContainer {
                    StreamyyyScrollView {
                        VStack(spacing: StreamyyySpacing.xl) {
                            StreamyyySection(title: "Grid Layout") {
                                StreamyyyGrid(columns: 2) {
                                    ForEach(0..<6) { index in
                                        StreamyyyCard {
                                            Text("Item \(index + 1)")
                                                .bodyMedium()
                                                .frame(height: 60)
                                        }
                                    }
                                }
                            }
                            
                            StreamyyySection(title: "List Layout") {
                                StreamyyyList(Array(0..<5).map { ListItem(id: $0, title: "Item \($0 + 1)") }) { item in
                                    StreamyyyCard {
                                        Text(item.title)
                                            .bodyMedium()
                                            .frame(height: 40)
                                    }
                                }
                            }
                            
                            StreamyyySection(title: "Empty State") {
                                StreamyyyEmptyState(
                                    title: "No Items",
                                    subtitle: "Add some items to get started",
                                    icon: "plus.circle",
                                    buttonTitle: "Add Item"
                                ) {
                                    print("Add item tapped")
                                }
                            }
                            .frame(height: 200)
                            
                            StreamyyySection(title: "Loading State") {
                                StreamyyyLoadingView(
                                    title: "Loading content...",
                                    style: .default
                                )
                            }
                            .frame(height: 100)
                        }
                    }
                }
                .navigationTitle("Layout Components")
            }
            .tabItem {
                Image(systemName: "rectangle.grid.2x2")
                Text("Layout")
            }
            .tag(0)
            
            StreamyyyNavigationView {
                StreamyyyScreenContainer {
                    StreamyyyEmptyState(
                        title: "Second Tab",
                        subtitle: "This is the second tab content",
                        icon: "star.fill"
                    )
                }
                .navigationTitle("Second Tab")
            }
            .tabItem {
                Image(systemName: "star")
                Text("Second")
            }
            .tag(1)
        }
    }
}

// MARK: - Helper Models
struct ListItem: Identifiable {
    let id: Int
    let title: String
}

#Preview {
    StreamyyyLayoutComponentsPreview()
}