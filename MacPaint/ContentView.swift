import SwiftUI

// MARK: - Data Models

enum Tool: String, CaseIterable, Identifiable {
    case selection = "cursorarrow.rays" // Selection Tool
    case pencil = "pencil"
    case eraser = "eraser.fill"
    case line = "line.diagonal"
    case rectangle = "rectangle"
    case ellipse = "oval"
    case polygon = "hexagon"
    case text = "textformat"
    case image = "photo" // Image Tool
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .selection: return "Select"
        case .pencil: return "Brushes"
        case .eraser: return "Eraser"
        case .line: return "Line"
        case .rectangle: return "Rect"
        case .ellipse: return "Oval"
        case .polygon: return "Polygon"
        case .text: return "Text"
        case .image: return "Image"
        }
    }
}

enum BrushType: String, CaseIterable, Identifiable {
    case standard = "paintbrush.fill"
    case stitch = "scribble"
    case spray = "aqi.high"
    case airbrush = "aqi.medium"
    case crayon = "pencil.tip"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .standard: return "Standard"
        case .stitch: return "Stitch"
        case .spray: return "Spray"
        case .airbrush: return "Airbrush"
        case .crayon: return "Crayon"
        }
    }
}

struct DrawingElement: Identifiable {
    let id = UUID()
    var tool: Tool
    var points: [CGPoint] // For Pencil/Eraser/Polygon
    var startPoint: CGPoint // For Shapes/Text/Image
    var endPoint: CGPoint   // For Shapes/Image
    var color: Color
    var lineWidth: CGFloat
    var brushType: BrushType = .standard
    
    // Text Tool Properties
    var text: String?
    
    // Image Tool Properties
    var insertedImage: NSImage?
    
    // Polygon Properties
    var isClosed: Bool = false
    
    // Add seed for deterministic random spray pattern
    var seed: Int = Int.random(in: 0...100000)
    
    // Helper to calculate bounds for hit-testing
    var bounds: CGRect {
        switch tool {
        case .pencil, .eraser, .polygon:
            guard !points.isEmpty else { return .zero }
            let xs = points.map { $0.x }
            let ys = points.map { $0.y }
            let minX = xs.min() ?? 0
            let minY = ys.min() ?? 0
            return CGRect(x: minX, y: minY, width: (xs.max() ?? 0) - minX, height: (ys.max() ?? 0) - minY)
        case .line, .rectangle, .ellipse, .image:
            return CGRect(from: startPoint, to: endPoint)
        case .selection, .text:
            // Approximate text bounds
            if tool == .text {
                return CGRect(x: startPoint.x, y: startPoint.y, width: 100, height: 50)
            }
            return .zero
        }
    }
}

// MARK: - Main View

struct ContentView: View {
    // State for the drawing
    @State private var currentElement: DrawingElement?
    @State private var elements: [DrawingElement] = []
    @State private var deletedElements: [DrawingElement] = [] // For Undo/Redo
    
    // Selection State
    @State private var selectionRect: CGRect?
    @State private var selectedElementIDs: Set<UUID> = []
    @State private var isDraggingSelection: Bool = false
    @State private var lastDragPosition: CGPoint = .zero
    @State private var selectionScale: CGFloat = 1.0
    @State private var selectionSnapshot: [UUID: DrawingElement] = [:]
    
    // Tools State
    @State private var selectedTool: Tool = .pencil
    @State private var selectedBrush: BrushType = .standard
    @State private var selectedColor: Color = .black
    @State private var canvasColor: Color = .white
    @State private var lineWidth: CGFloat = 5.0
    @State private var sidebarWidth: CGFloat = 220
    
    // Canvas Geometry State
    @State private var canvasSize: CGSize = CGSize(width: 800, height: 600)
    @State private var initialCanvasSize: CGSize? = nil
    
    // Text & Image Tool State
    @State private var pendingText: String = ""
    @State private var textPosition: CGPoint?
    @FocusState private var isTextFocused: Bool
    
    @State private var isShowingImagePicker: Bool = false
    @State private var pendingImagePosition: CGPoint?
    
    // Zoom State
    @State private var zoomScale: CGFloat = 1.0
    
    // Recent Colors
    @State private var recentColors: [Color] = [.red, .blue, .green, .cyan, .black]
    
    var body: some View {
        HStack(spacing: 0) {
            // 1. Sidebar / Control Panel
            controlPanel
                .frame(width: sidebarWidth)
                .background(Color(nsColor: .windowBackgroundColor))
                .zIndex(2)
            
            // 2. Resize Handle (Slider)
            resizeHandle
                .zIndex(3)
            
            // 3. The Canvas Area
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    
                    // The Actual Drawing Area
                    ZStack(alignment: .topLeading) {
                        canvasColor
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        
                        Canvas { context, size in
                            // Draw saved elements
                            for element in elements {
                                drawElement(element, in: context)
                                
                                // Highlight selected elements
                                if selectedElementIDs.contains(element.id) {
                                    let bounds = element.bounds
                                    let highlightPath = Path(bounds)
                                    context.stroke(highlightPath, with: .color(.blue), style: StrokeStyle(lineWidth: 1 / zoomScale, dash: [5 / zoomScale]))
                                }
                            }
                            
                            // Draw current drawing element
                            if let current = currentElement {
                                drawElement(current, in: context)
                            }
                            
                            // Draw Selection Marquee
                            if let rect = selectionRect {
                                let path = Path(rect)
                                context.stroke(path, with: .color(.gray), style: StrokeStyle(lineWidth: 1 / zoomScale, dash: [4 / zoomScale]))
                                context.fill(path, with: .color(.blue.opacity(0.1)))
                            }
                        }
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .gesture(canvasGesture)
                        
                        // Text Input Overlay
                        if let pos = textPosition {
                            TextField("Type here...", text: $pendingText)
                                .font(.system(size: lineWidth * 3))
                                .foregroundStyle(selectedColor)
                                .textFieldStyle(.plain)
                                .padding(4)
                                .background(Color.white.opacity(0.8))
                                .border(Color.blue, width: 1)
                                .fixedSize()
                                .position(x: pos.x * zoomScale, y: pos.y * zoomScale)
                                .focused($isTextFocused)
                                .onSubmit { commitText() }
                                .onAppear { isTextFocused = true }
                        }
                    }
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    
                    // --- Canvas Resize Handles ---
                    resizeHandleView(cursor: .resizeLeftRight)
                        .position(x: canvasSize.width, y: canvasSize.height / 2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if initialCanvasSize == nil { initialCanvasSize = canvasSize }
                                    guard let start = initialCanvasSize else { return }
                                    canvasSize.width = max(100, start.width + value.translation.width)
                                }
                                .onEnded { _ in initialCanvasSize = nil }
                        )
                    
                    resizeHandleView(cursor: .resizeUpDown)
                        .position(x: canvasSize.width / 2, y: canvasSize.height)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if initialCanvasSize == nil { initialCanvasSize = canvasSize }
                                    guard let start = initialCanvasSize else { return }
                                    canvasSize.height = max(100, start.height + value.translation.height)
                                }
                                .onEnded { _ in initialCanvasSize = nil }
                        )
                    
                    resizeHandleView(cursor: .crosshair)
                        .position(x: canvasSize.width, y: canvasSize.height)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if initialCanvasSize == nil { initialCanvasSize = canvasSize }
                                    guard let start = initialCanvasSize else { return }
                                    canvasSize.width = max(100, start.width + value.translation.width)
                                    canvasSize.height = max(100, start.height + value.translation.height)
                                }
                                .onEnded { _ in initialCanvasSize = nil }
                        )
                }
                .frame(width: canvasSize.width + 20, height: canvasSize.height + 20, alignment: .topLeading)
                .scaleEffect(zoomScale, anchor: .topLeading)
                .frame(width: (canvasSize.width + 20) * zoomScale, height: (canvasSize.height + 20) * zoomScale)
            }
            .background(Color(nsColor: .underPageBackgroundColor))
            .onHover { isHovering in
                if isHovering {
                    switch selectedTool {
                    case .selection: NSCursor.arrow.set()
                    case .text: NSCursor.iBeam.set()
                    default: NSCursor.crosshair.set()
                    }
                } else {
                    NSCursor.arrow.set()
                }
            }
            .contextMenu {
                if selectedTool == .pencil {
                    Button { selectedTool = .eraser } label: { Label("Switch to Eraser", systemImage: "eraser.fill") }
                    Divider()
                    Text("Brush Style")
                    ForEach(BrushType.allCases) { brush in
                        Button { selectedBrush = brush } label: {
                            if selectedBrush == brush { Label(brush.label, systemImage: "checkmark") } else { Text(brush.label) }
                        }
                    }
                } else if selectedTool == .eraser {
                    Button { selectedTool = .pencil } label: { Label("Switch to Pencil", systemImage: "pencil") }
                }
            }
            // --- File Importer for Images ---
            .fileImporter(isPresented: $isShowingImagePicker, allowedContentTypes: [.image]) { result in
                switch result {
                case .success(let url):
                    if let nsImage = NSImage(contentsOf: url) {
                        insertImage(nsImage)
                    }
                case .failure(let error):
                    print("Error selecting image: \(error.localizedDescription)")
                }
            }
        }
        .coordinateSpace(name: "mainContainer")
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // MARK: - Logic & Gestures
    
    var canvasGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = value.location
                
                // --- Tool Specific Drag Logic ---
                if selectedTool == .text || selectedTool == .image { return }
                
                if selectedTool == .selection {
                    var isMoving = isDraggingSelection
                    
                    if !isMoving {
                        if let rect = selectionRect, rect.contains(value.startLocation), !selectedElementIDs.isEmpty {
                            isMoving = true
                            isDraggingSelection = true
                            lastDragPosition = value.startLocation
                        }
                    }
                    
                    if isMoving {
                        let deltaX = point.x - lastDragPosition.x
                        let deltaY = point.y - lastDragPosition.y
                        moveSelectedElements(offset: CGSize(width: deltaX, height: deltaY))
                        if selectionRect != nil {
                            selectionRect = selectionRect!.offsetBy(dx: deltaX, dy: deltaY)
                        }
                        lastDragPosition = point
                    } else {
                        if selectionRect == nil || selectedElementIDs.isEmpty {
                            selectionRect = CGRect(origin: value.startLocation, size: .zero)
                        }
                        selectedElementIDs.removeAll()
                        selectionSnapshot.removeAll()
                        selectionRect = CGRect(from: value.startLocation, to: point)
                    }
                    return
                }
                
                if selectedTool == .polygon { return }
                
                if !selectedElementIDs.isEmpty {
                    selectedElementIDs.removeAll()
                    selectionSnapshot.removeAll()
                }
                
                if currentElement == nil {
                    currentElement = DrawingElement(
                        tool: selectedTool,
                        points: [point],
                        startPoint: point,
                        endPoint: point,
                        color: selectedTool == .eraser ? canvasColor : selectedColor,
                        lineWidth: lineWidth,
                        brushType: selectedBrush
                    )
                    deletedElements.removeAll()
                } else {
                    if selectedTool == .pencil || selectedTool == .eraser {
                        currentElement?.points.append(point)
                    } else {
                        currentElement?.endPoint = point
                    }
                }
            }
            .onEnded { value in
                let point = value.location
                
                // --- Tool Specific End Logic ---
                if selectedTool == .text {
                    if textPosition != nil { commitText() }
                    textPosition = point
                    pendingText = ""
                    return
                }
                
                if selectedTool == .image {
                    pendingImagePosition = point
                    isShowingImagePicker = true
                    return
                }
                
                if selectedTool == .polygon {
                    if currentElement == nil {
                        currentElement = DrawingElement(tool: .polygon, points: [point], startPoint: point, endPoint: point, color: selectedColor, lineWidth: lineWidth)
                    } else {
                        if let first = currentElement?.points.first, distance(from: point, to: first) < 20 {
                            var closedPoly = currentElement!
                            closedPoly.isClosed = true
                            elements.append(closedPoly)
                            addToRecentColors(selectedColor)
                            currentElement = nil
                        } else {
                            currentElement?.points.append(point)
                        }
                    }
                    return
                }
                
                if selectedTool == .selection {
                    isDraggingSelection = false
                    if let rect = selectionRect, selectedElementIDs.isEmpty {
                        let hitElements = elements.filter { $0.bounds.intersects(rect) }
                        selectedElementIDs = Set(hitElements.map { $0.id })
                        selectionSnapshot = Dictionary(uniqueKeysWithValues: hitElements.map { ($0.id, $0) })
                        selectionScale = 1.0
                    }
                    return
                }
                
                if let element = currentElement {
                    elements.append(element)
                    if selectedTool != .eraser { addToRecentColors(selectedColor) }
                }
                currentElement = nil
            }
    }
    
    func commitText() {
        guard let pos = textPosition, !pendingText.isEmpty else {
            textPosition = nil
            return
        }
        let newElement = DrawingElement(
            tool: .text,
            points: [],
            startPoint: pos,
            endPoint: pos,
            color: selectedColor,
            lineWidth: lineWidth,
            text: pendingText
        )
        elements.append(newElement)
        textPosition = nil
        pendingText = ""
        addToRecentColors(selectedColor)
    }
    
    func insertImage(_ nsImage: NSImage) {
        // Calculate a reasonable default size (e.g. max 300px width/height maintaining aspect)
        let size = nsImage.size
        let maxDim: CGFloat = 300
        let aspect = size.width / size.height
        
        let width = size.width > size.height ? maxDim : maxDim * aspect
        let height = size.width > size.height ? maxDim / aspect : maxDim
        
        let start = pendingImagePosition ?? CGPoint(x: 100, y: 100)
        let end = CGPoint(x: start.x + width, y: start.y + height)
        
        let newElement = DrawingElement(
            tool: .image,
            points: [],
            startPoint: start,
            endPoint: end,
            color: .clear,
            lineWidth: 0,
            insertedImage: nsImage
        )
        
        elements.append(newElement)
        
        // Auto-select the newly inserted image
        selectedTool = .selection
        selectedElementIDs = [newElement.id]
        selectionSnapshot = [newElement.id: newElement]
        selectionRect = newElement.bounds
        selectionScale = 1.0
    }
    
    func moveSelectedElements(offset: CGSize) {
        for index in elements.indices {
            if selectedElementIDs.contains(elements[index].id) {
                var element = elements[index]
                moveElement(&element, offset: offset)
                elements[index] = element
            }
        }
        
        for id in selectionSnapshot.keys {
            if var snapshotElement = selectionSnapshot[id] {
                moveElement(&snapshotElement, offset: offset)
                selectionSnapshot[id] = snapshotElement
            }
        }
    }
    
    func moveElement(_ element: inout DrawingElement, offset: CGSize) {
        if !element.points.isEmpty {
            element.points = element.points.map { CGPoint(x: $0.x + offset.width, y: $0.y + offset.height) }
        }
        element.startPoint.x += offset.width
        element.startPoint.y += offset.height
        element.endPoint.x += offset.width
        element.endPoint.y += offset.height
    }
    
    func drawElement(_ element: DrawingElement, in context: GraphicsContext) {
        var path = Path()
        
        switch element.tool {
        case .pencil, .eraser:
            if element.tool == .pencil && element.brushType == .spray {
                for (index, point) in element.points.enumerated() {
                    let hash = abs(element.seed ^ index)
                    let count = Int(element.lineWidth) * 2
                    for i in 0..<count {
                        let subHash = (hash &+ i) * 1664525
                        let rand1 = Double(subHash & 0xFF) / 255.0
                        let rand2 = Double((subHash >> 8) & 0xFF) / 255.0
                        let angle = rand1 * 2 * .pi
                        let radius = sqrt(rand2) * element.lineWidth
                        let dx = CGFloat(cos(angle) * radius)
                        let dy = CGFloat(sin(angle) * radius)
                        path.addRect(CGRect(x: point.x + dx, y: point.y + dy, width: 1.5, height: 1.5))
                    }
                }
            } else {
                path.addLines(element.points)
            }
        case .line:
            path.move(to: element.startPoint)
            path.addLine(to: element.endPoint)
        case .rectangle:
            path.addRect(CGRect(from: element.startPoint, to: element.endPoint))
        case .ellipse:
            path.addEllipse(in: CGRect(from: element.startPoint, to: element.endPoint))
        case .polygon:
            if !element.points.isEmpty {
                path.addLines(element.points)
                if element.isClosed { path.closeSubpath() }
            }
        case .text:
            if let text = element.text {
                let fontSize = element.lineWidth * 3
                context.draw(
                    Text(text).font(.system(size: fontSize)).foregroundColor(element.color),
                    at: element.startPoint,
                    anchor: .topLeading
                )
            }
            return
        case .image:
            if let img = element.insertedImage {
                let rect = CGRect(from: element.startPoint, to: element.endPoint)
                context.draw(Image(nsImage: img), in: rect)
            }
            return
        case .selection:
            break
        }
        
        var strokeColor = (element.tool == .eraser) ? canvasColor : element.color
        var style = StrokeStyle(lineWidth: element.lineWidth, lineCap: .round, lineJoin: .round)
        
        if element.tool == .pencil {
            switch element.brushType {
            case .standard: style.lineCap = .round
            case .stitch: style.lineCap = .round; style.dash = [element.lineWidth * 2, element.lineWidth]
            case .spray:
                context.fill(path, with: .color(strokeColor))
                return
            case .airbrush: style.lineCap = .round; strokeColor = strokeColor.opacity(0.2)
            case .crayon: style.lineCap = .butt; strokeColor = strokeColor.opacity(0.7); style.dash = [1, 2]
            }
        }
        
        context.stroke(path, with: .color(strokeColor), style: style)
    }
    
    // MARK: - Logic Helpers
    
    func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        return sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
    }
    
    // MARK: - Selection Operations
    
    func deleteSelected() {
        elements.removeAll { selectedElementIDs.contains($0.id) }
        selectedElementIDs.removeAll()
        selectionSnapshot.removeAll()
    }
    
    func colorSelected(_ color: Color) {
        for (index, element) in elements.enumerated() {
            if selectedElementIDs.contains(element.id) {
                var newElement = element
                newElement.color = color
                elements[index] = newElement
                
                if var snap = selectionSnapshot[element.id] {
                    snap.color = color
                    selectionSnapshot[element.id] = snap
                }
            }
        }
    }
    
    func applyResize(scale: CGFloat) {
        guard !selectionSnapshot.isEmpty else { return }
        
        let allBounds = selectionSnapshot.values.map { $0.bounds }
        guard let unionRect = allBounds.first else { return }
        let totalBounds = allBounds.dropFirst().reduce(unionRect) { $0.union($1) }
        let center = CGPoint(x: totalBounds.midX, y: totalBounds.midY)
        
        for (index, _) in elements.enumerated() {
            let id = elements[index].id
            if let snapshotElement = selectionSnapshot[id] {
                var newElement = snapshotElement
                
                let transformPoint = { (p: CGPoint) -> CGPoint in
                    let dx = p.x - center.x
                    let dy = p.y - center.y
                    return CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
                }
                
                if snapshotElement.tool == .pencil || snapshotElement.tool == .eraser || snapshotElement.tool == .polygon {
                    newElement.points = snapshotElement.points.map(transformPoint)
                } else if snapshotElement.tool == .text {
                    newElement.startPoint = transformPoint(snapshotElement.startPoint)
                    newElement.lineWidth = snapshotElement.lineWidth * scale
                } else {
                    newElement.startPoint = transformPoint(snapshotElement.startPoint)
                    newElement.endPoint = transformPoint(snapshotElement.endPoint)
                }
                
                elements[index] = newElement
            }
        }
        
        let newWidth = totalBounds.width * scale
        let newHeight = totalBounds.height * scale
        selectionRect = CGRect(x: center.x - newWidth/2, y: center.y - newHeight/2, width: newWidth, height: newHeight)
    }
    
    // MARK: - Subviews
    
    func resizeHandleView(cursor: NSCursor) -> some View {
        Rectangle()
            .fill(Color.white)
            .border(Color.black, width: 1)
            .frame(width: 8, height: 8)
            .onHover { inside in
                if inside { cursor.set() } else { NSCursor.arrow.set() }
            }
    }
    
    var resizeHandle: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .overlay(Rectangle().fill(Color.clear).frame(width: 10).contentShape(Rectangle()))
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("mainContainer"))
                    .onChanged { value in
                        let newWidth = value.location.x
                        if newWidth >= 150 && newWidth <= 400 { sidebarWidth = newWidth }
                    }
            )
    }
    
    var controlPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Created with ♡").font(.headline).frame(maxWidth: .infinity, alignment: .center).padding(.top, 5)
                Divider()
                
                // ZOOM
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Zoom", systemImage: "magnifyingglass").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(zoomScale * 100))%").font(.caption).monospacedDigit()
                    }
                    HStack {
                        Button(action: { if zoomScale > 0.5 { zoomScale -= 0.25 } }) { Image(systemName: "minus.magnifyingglass") }
                        Slider(value: $zoomScale, in: 0.5...4.0)
                        Button(action: { if zoomScale < 4.0 { zoomScale += 0.25 } }) { Image(systemName: "plus.magnifyingglass") }
                    }
                }
                Divider()
                
                // SELECTION ACTIONS
                if selectedTool == .selection && !selectedElementIDs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Selection Actions", systemImage: "slider.horizontal.3").font(.subheadline).bold().foregroundStyle(.blue)
                        Button(action: deleteSelected) {
                            Label("Delete Selected", systemImage: "trash").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(.red)
                        .keyboardShortcut(.delete, modifiers: [])
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Resize")
                                Spacer()
                                Text(String(format: "%.1fx", selectionScale)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            }
                            Slider(value: Binding(
                                get: { selectionScale },
                                set: { newVal in
                                    selectionScale = newVal
                                    applyResize(scale: newVal)
                                }
                            ), in: 0.1...3.0) {
                                Text("Resize")
                            } minimumValueLabel: { Image(systemName: "minus") } maximumValueLabel: { Image(systemName: "plus") }
                        }
                        
                        ColorPicker("Change Color", selection: Binding(
                            get: { selectedColor },
                            set: { selectedColor = $0; colorSelected($0) }
                        ))
                    }
                    .padding(10).background(Color.blue.opacity(0.1)).cornerRadius(8)
                    Divider()
                }
                
                // TOOLS
                VStack(alignment: .leading, spacing: 10) {
                    Label("Tools", systemImage: "hammer.fill").font(.subheadline).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Tool.allCases) { tool in
                            Button(action: {
                                if selectedTool == .text { commitText() }
                                selectedTool = tool
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: tool.rawValue).font(.system(size: 20))
                                    Text(tool.label).font(.caption)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(selectedTool == tool ? Color.accentColor.opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedTool == tool ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .applyToolShortcut(tool)
                        }
                    }
                }
                Divider()
                
                // BRUSH STYLE
                if selectedTool == .pencil {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Brush Style", systemImage: "paintpalette").font(.subheadline).foregroundStyle(.secondary)
                        Menu {
                            ForEach(BrushType.allCases) { brush in
                                Button(action: { selectedBrush = brush }) {
                                    Label(brush.label, systemImage: brush.rawValue)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedBrush.rawValue)
                                Text(selectedBrush.label)
                                Spacer()
                                Image(systemName: "chevron.down").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(8).background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        }
                        .menuStyle(.borderlessButton)
                    }
                    Divider()
                }
                
                // COLOR PICKER
                VStack(alignment: .leading, spacing: 10) {
                    Label("Brush Color", systemImage: "paintpalette.fill").font(.subheadline).foregroundStyle(.secondary)
                    ColorPicker("Selected Color", selection: $selectedColor).labelsHidden()
                    if !recentColors.isEmpty {
                        Text("Recent").font(.caption2).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(recentColors, id: \.self) { color in
                                Button(action: { selectedColor = color }) {
                                    Circle().fill(color).frame(width: 24, height: 24).overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }.disabled(selectedTool == .eraser || (selectedTool == .selection && selectedElementIDs.isEmpty))
                
                Group {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Canvas", systemImage: "square.dashed").font(.subheadline).foregroundStyle(.secondary)
                        HStack { Text("Background").font(.caption); Spacer(); ColorPicker("", selection: $canvasColor).labelsHidden() }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Label("Stroke", systemImage: "scribble").font(.subheadline).foregroundStyle(.secondary); Spacer(); Text(String(format: "%.0f", lineWidth)).monospacedDigit().foregroundStyle(.secondary) }
                        Slider(value: $lineWidth, in: 1...50) { Text("Size") }
                        
//                        // Hidden Stroke Shortcuts
//                        Button(action: { lineWidth = min(50, lineWidth + 1) }) { EmptyView() }
//                            .keyboardShortcut("=", modifiers: [])
//                        Button(action: { lineWidth = max(1, lineWidth - 1) }) { EmptyView() }
//                            .keyboardShortcut("-", modifiers: [])
                    }
                    Divider()
                    VStack(spacing: 12) {
                        HStack {
                            Button(action: undo) {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .disabled(elements.isEmpty)
                            .keyboardShortcut("z", modifiers: .command) // Undo

                            Button(action: redo) {
                                Image(systemName: "arrow.uturn.forward")
                            }
                            .disabled(deletedElements.isEmpty)
                            .keyboardShortcut("z", modifiers: [.command, .shift]) // Redo
                        }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                        
                        Button(action: clearCanvas) {
                            Label("Clear All", systemImage: "trash").frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .keyboardShortcut("x", modifiers: [])
                        
                        Button(action: saveImage) { Label("Export PNG", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity) }.controlSize(.large).buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Standard Actions
    
    func addToRecentColors(_ color: Color) {
        if let index = recentColors.firstIndex(of: color) { recentColors.remove(at: index) }
        recentColors.insert(color, at: 0)
        if recentColors.count > 5 { recentColors.removeLast() }
    }
    
    func undo() { guard let last = elements.popLast() else { return }; deletedElements.append(last) }
    func redo() { guard let last = deletedElements.popLast() else { return }; elements.append(last) }
    func clearCanvas() { deletedElements = elements; elements.removeAll(); selectedElementIDs.removeAll() }
    
    func saveImage() {
        let size = canvasSize
        let currentElements = elements
        let currentBg = canvasColor
        
        let renderer = ImageRenderer(content:
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(currentBg))
                
                for element in currentElements {
                     var path = Path()
                     if element.tool == .pencil && element.brushType == .spray {
                        for (index, point) in element.points.enumerated() {
                            let hash = abs(element.seed ^ index)
                            let count = Int(element.lineWidth) * 2
                            for i in 0..<count {
                                let subHash = (hash &+ i) * 1664525
                                let rand1 = Double(subHash & 0xFF) / 255.0
                                let rand2 = Double((subHash >> 8) & 0xFF) / 255.0
                                let angle = rand1 * 2 * .pi
                                let radius = sqrt(rand2) * element.lineWidth
                                let dx = CGFloat(cos(angle) * radius)
                                let dy = CGFloat(sin(angle) * radius)
                                path.addRect(CGRect(x: point.x + dx, y: point.y + dy, width: 1.5, height: 1.5))
                            }
                        }
                        context.fill(path, with: .color(element.color))
                     } else if element.tool == .text {
                        if let text = element.text {
                            let fontSize = element.lineWidth * 3
                            context.draw(
                                Text(text).font(.system(size: fontSize)).foregroundColor(element.color),
                                at: element.startPoint,
                                anchor: .topLeading
                            )
                        }
                     } else if element.tool == .image {
                        if let img = element.insertedImage {
                            let rect = CGRect(from: element.startPoint, to: element.endPoint)
                            context.draw(Image(nsImage: img), in: rect)
                        }
                     } else if element.tool == .polygon {
                        if !element.points.isEmpty {
                            path.addLines(element.points)
                            if element.isClosed { path.closeSubpath() }
                            context.stroke(path, with: .color(element.color), style: StrokeStyle(lineWidth: element.lineWidth, lineCap: .round, lineJoin: .round))
                        }
                     } else {
                        switch element.tool {
                        case .pencil, .eraser: path.addLines(element.points)
                        case .line: path.move(to: element.startPoint); path.addLine(to: element.endPoint)
                        case .rectangle: path.addRect(CGRect(from: element.startPoint, to: element.endPoint))
                        case .ellipse: path.addEllipse(in: CGRect(from: element.startPoint, to: element.endPoint))
                        default: break
                        }
                        
                        var strokeColor = (element.tool == .eraser) ? currentBg : element.color
                        var style = StrokeStyle(lineWidth: element.lineWidth, lineCap: .round, lineJoin: .round)
                        
                        if element.tool == .pencil {
                            switch element.brushType {
                            case .standard: style.lineCap = .round
                            case .stitch: style.lineCap = .round; style.dash = [element.lineWidth * 2, element.lineWidth]
                            case .spray: break
                            case .airbrush: style.lineCap = .round; strokeColor = strokeColor.opacity(0.2)
                            case .crayon: style.lineCap = .butt; strokeColor = strokeColor.opacity(0.7); style.dash = [1, 2]
                            }
                        }
                        context.stroke(path, with: .color(strokeColor), style: style)
                     }
                }
            }.frame(width: size.width, height: size.height)
        )
        if let nsImage = renderer.nsImage { saveNSImage(nsImage) }
    }
    
    func saveNSImage(_ image: NSImage) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "MyDrawing.png"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let tiffData = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData), let pngData = bitmap.representation(using: .png, properties: [:]) { try? pngData.write(to: url) }
            }
        }
    }
}

// MARK: - View Modifiers

extension View {
    @ViewBuilder
    func applyToolShortcut(_ tool: Tool) -> some View {
        switch tool {
        case .pencil: self.keyboardShortcut("b", modifiers: [])
        case .selection: self.keyboardShortcut("s", modifiers: [])
        case .eraser: self.keyboardShortcut("e", modifiers: [])
        case .rectangle: self.keyboardShortcut("r", modifiers: [])
        case .ellipse: self.keyboardShortcut("o", modifiers: [])
        case .polygon: self.keyboardShortcut("p", modifiers: [])
        case .line: self.keyboardShortcut("l", modifiers: [])
        case .text: self.keyboardShortcut("t", modifiers: [])
        default: self
        }
    }
}

// Helper extension to create CGRect from two points
extension CGRect {
    init(from p1: CGPoint, to p2: CGPoint) {
        let x = min(p1.x, p2.x)
        let y = min(p1.y, p2.y)
        let width = abs(p1.x - p2.x)
        let height = abs(p1.y - p2.y)
        self.init(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
