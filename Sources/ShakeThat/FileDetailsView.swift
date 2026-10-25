import AppKit
import ShakeCore
import SwiftUI

/// The details panel: the shelf's files with their size and type details, as a grid or a list.
struct FileDetailsView: View {
    @ObservedObject var model: FileDetailsModel

    private static let width: CGFloat = 360
    private static let headerHeight: CGFloat = 44
    private static let maxContentHeight: CGFloat = 400
    private static let padding: CGFloat = 12
    private static let gridCellHeight: CGFloat = 108
    private static let gridSpacing: CGFloat = 12
    private static let listRowHeight: CGFloat = 40

    /// Fits the files up to a maximum height, then scrolls.
    static func size(for model: FileDetailsModel) -> NSSize {
        let count = model.files.count
        let content: CGFloat
        switch model.layout {
        case .grid:
            let rows = CGFloat((count + 1) / 2)
            content = rows * gridCellHeight + max(rows - 1, 0) * gridSpacing
        case .list:
            content = CGFloat(count) * listRowHeight
        }
        return NSSize(width: width, height: headerHeight + min(content + 2 * padding, maxContentHeight))
    }

    var body: some View {
        let size = Self.size(for: model)
        VStack(spacing: 0) {
            header
            ScrollView {
                switch model.layout {
                case .grid: grid
                case .list: list
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var header: some View {
        ZStack {
            Text(model.header)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Picker("Layout", selection: $model.layout) {
                    Image(systemName: "square.grid.2x2").help("Show files as icons").tag(FileDetailsModel.Layout.grid)
                    Image(systemName: "list.bullet").help("Show files in a list").tag(FileDetailsModel.Layout.list)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
        .padding(.horizontal, Self.padding)
        .frame(height: Self.headerHeight)
    }

    private var grid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Self.gridSpacing), count: 2),
            spacing: Self.gridSpacing
        ) {
            ForEach(model.files) { file in
                VStack(spacing: 4) {
                    Image(nsImage: file.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                    Text(file.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(file.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: Self.gridCellHeight)
                .help(file.name)
            }
        }
        .padding(Self.padding)
    }

    private var list: some View {
        LazyVStack(spacing: 0) {
            ForEach(model.files) { file in
                HStack(spacing: 10) {
                    Image(nsImage: file.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                    Text(file.name)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 1) {
                        if let size = file.size {
                            Text(FileDetailsFormat.size(size))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        if let detail = file.detail {
                            Text(detail)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(height: Self.listRowHeight)
                .help(file.name)
            }
        }
        .padding(Self.padding)
    }
}

/// Shows the details panel in a popover below the shelf's file count.
@MainActor
final class FileDetailsPopover {
    let model = FileDetailsModel()
    private let popover = NSPopover()

    init() {
        let controller = NSViewController()
        controller.view = FirstMouseHostingView(rootView: FileDetailsView(model: model))
        popover.contentViewController = controller
        popover.behavior = .transient
        model.onResize = { [weak self] in self?.resize() }
        resize()
    }

    func toggle(below view: NSView) {
        if popover.isShown {
            close()
        } else {
            popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
    }

    func close() {
        popover.close()
    }

    private func resize() {
        popover.contentSize = FileDetailsView.size(for: model)
    }
}

/// The shelf never becomes the active app, so the first click in the panel must already work.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
