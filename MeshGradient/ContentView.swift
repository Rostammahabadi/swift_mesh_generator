import SwiftUI

struct MeshPoint: Identifiable {
    let id = UUID()
    var position: SIMD2<Float>
    var color: Color
}

struct ColorPickerPopover: View {
    @Binding var color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Choose Color")
                .font(.headline)
            
            ColorPicker("", selection: $color)
                .labelsHidden()
                .frame(width: 200)
            
            // Add a color palette for quick selection
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                ForEach([
                    Color.red, .orange, .yellow, .green, .blue,
                    Color.purple, .pink, .cyan, .mint, .indigo
                ], id: \.self) { presetColor in
                    Circle()
                        .fill(presetColor)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        .onTapGesture {
                            color = presetColor
                        }
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

struct PointOverlay: View {
    let point: MeshPoint
    @Binding var position: SIMD2<Float>
    let size: CGSize
    @Binding var color: Color
    @State private var showingColorPicker = false
    
    
    
    private func constrainPosition(_ newPosition: SIMD2<Float>) -> SIMD2<Float> {
        // If it's a corner point, return the original position without any changes
        let isCorner = (point.position.x == 0 && point.position.y == 0) || // top-left
        (point.position.x == 1 && point.position.y == 0) || // top-right
        (point.position.x == 0 && point.position.y == 1) || // bottom-left
        (point.position.x == 1 && point.position.y == 1)    // bottom-right
        
        if isCorner {
            return point.position
        }
        
        var constrained = newPosition
        
        // Check if point is on vertical edge
        if point.position.x == 0 || point.position.x == 1 {
            constrained.x = point.position.x  // Keep x fixed
            constrained.y = min(max(newPosition.y, 0), 1)  // Constrain y to [0,1]
        }
        
        // Check if point is on horizontal edge
        if point.position.y == 0 || point.position.y == 1 {
            constrained.y = point.position.y  // Keep y fixed
            constrained.x = min(max(newPosition.x, 0), 1)  // Constrain x to [0,1]
        }
        
        return constrained
    }
    
    
    var body: some View {
        ZStack {
            // Outer shadow for better visibility
            Circle()
                .fill(Color.black.opacity(0.3))
                .frame(width: 16, height: 16)
                .blur(radius: 1)
            
            // Main point circle with multiple strokes
            Circle()
                .fill(point.color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.5), lineWidth: 1)
                        .padding(-1)
                )
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
        }
        .position(
            x: CGFloat(point.position.x) * (size.width - 16) + 8,
            y: CGFloat(point.position.y) * (size.height - 16) + 8
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newX = Float(value.location.x / size.width)
                    let newY = Float(value.location.y / size.height)
                    position = constrainPosition(SIMD2<Float>(newX, newY))
                }
        )
        .onTapGesture {
            showingColorPicker.toggle()
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerSheet(color: $color)
        }
    }
}



enum AnimationType: String, CaseIterable {
    case wave = "Wave"
    case rotate = "Rotate"
    case pulse = "Pulse"
    case bounce = "Bounce"
    case spiral = "Spiral"
}

struct ColorPickerSheet: View {
    @Binding var color: Color
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            // Native macOS title bar style
            HStack {
                Text("Choose Color")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Native color picker with label
            ColorPicker("Color", selection: $color)
                .padding(.horizontal)
            
            // Preset colors in grid
            GroupBox {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                    ForEach([
                        Color.red, .orange, .yellow, .green, .blue,
                        Color.purple, .pink, .cyan, .mint, .indigo
                    ], id: \.self) { presetColor in
                        Circle()
                            .fill(presetColor)
                            .frame(width: 30, height: 30)
                            .contentShape(Circle())
                            .onTapGesture {
                                color = presetColor
                                dismiss()
                            }
                    }
                }
                .padding(8)
            } label: {
                Text("Preset Colors")
                    .font(.system(size: 11))
            }
            .padding(.horizontal)
            
            // Native macOS button style
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 300)
        .background(Color(.windowBackgroundColor))
    }
}



struct MeshGradientEditor: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var meshPoints: [MeshPoint] = []
    @State private var width: Int = 3
    @State private var height: Int = 3
    @State private var smoothColors: Bool = true
    @State private var isAnimating: Bool = false
    @State private var selectedAnimationType: AnimationType = .wave
    @State private var animationSpeed: Double = 1.0
    @State private var animationIntensity: Double = 1.0
    @State private var showNotification = false
    
    private var points: [SIMD2<Float>] {
        if !isAnimating {
            return meshPoints.map { $0.position }
        }
        
        var result: [SIMD2<Float>] = []
        let timeInterval = Date().timeIntervalSince1970 * animationSpeed
        
        for (_, basePoint) in meshPoints.enumerated() {
            let xPos = basePoint.position.x
            let yPos = basePoint.position.y
            
            var offsetX: Float = 0
            var offsetY: Float = 0
            
            if (xPos == 0 && yPos == 0) || // top-left
                (xPos == 1 && yPos == 0) || // top-right
                (xPos == 0 && yPos == 1) || // bottom-left
                (xPos == 1 && yPos == 1)    // bottom-right
            {
                result.append(basePoint.position)
                continue
            }
            
            let intensity = Float(animationIntensity) * 0.1
            
            switch selectedAnimationType {
            case .wave:
                offsetX = Float(sin(timeInterval + Double(yPos) * 0.5)) * intensity
                offsetY = Float(cos(timeInterval + Double(xPos) * 0.5)) * intensity
            case .rotate:
                let centerX: Float = 0.5
                let centerY: Float = 0.5
                let dx = xPos - centerX
                let dy = yPos - centerY
                let angle = Float(timeInterval)
                
                offsetX = (cos(angle) * dx - sin(angle) * dy) * 2
                offsetY = (sin(angle) * dx + cos(angle) * dy) * 2
            case .pulse:
                let scale = Float(1.0 + sin(timeInterval) * Double(intensity))
                offsetX = (xPos - 0.5) * (scale - 1) * 2
                offsetY = (yPos - 0.5) * (scale - 1) * 2
            case .bounce:
                offsetY = Float(abs(sin(timeInterval + Double(xPos) * 0.3))) * intensity * 2
            case .spiral:
                let centerX: Float = 0.5
                let centerY: Float = 0.5
                let dx = xPos - centerX
                let dy = yPos - centerY
                let distance = sqrt(dx * dx + dy * dy)
                
                let angle = Float(timeInterval) + distance * 10
                let spiralScale = 1.0 + sin(timeInterval) * Double(intensity)
                offsetX = (cos(angle) * dx - sin(angle) * dy) * Float(spiralScale)
                offsetY = (sin(angle) * dx + cos(angle) * dy) * Float(spiralScale)
            }
            
            result.append(SIMD2<Float>(
                min(max(xPos + offsetX, 0), 1),
                min(max(yPos + offsetY, 0), 1)
            ))
        }
        return result
    }
    
    private var colors: [Color] {
        meshPoints.map { $0.color }
    }
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(spacing: 20) {
                    previewSection
                        .frame(minWidth: 400)
                    controlSection
                }
                .padding()
            } else {
                VStack {
                    previewSection
                    controlSection
                }
                .padding()
            }
        }
        .frame(minWidth: 300, idealWidth: 800, maxWidth: .infinity,
               minHeight: 400, idealHeight: 600, maxHeight: .infinity)
        .onAppear {
            initializePoints()
        }
    }
    
    
    private var previewSection: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                ZStack {
                    MeshGradient(
                        width: width,
                        height: height,
                        points: points,
                        colors: colors,
                        smoothsColors: smoothColors
                    )
                    .zIndex(0)
                    
                    if !isAnimating {
                        ForEach(Array(meshPoints.indices), id: \.self) { index in
                            PointOverlay(
                                point: meshPoints[index],
                                position: Binding(
                                    get: { meshPoints[index].position },
                                    set: { meshPoints[index].position = $0 }
                                ),
                                size: geometry.size,
                                color: Binding(
                                    get: { meshPoints[index].color },
                                    set: { meshPoints[index].color = $0 }
                                )
                            )
                            .zIndex(1)
                        }
                    }
                }
            }
            .frame(minHeight: 300)
            .cornerRadius(0)
        }
    }
    
    private var animationControlsSection: some View {
        Section("Animation Controls") {
            Toggle("Animate Mesh", isOn: $isAnimating)
            Picker("Animation Type", selection: $selectedAnimationType) {
                ForEach(AnimationType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            VStack {
                Text("Speed: \(String(format: "%.1f", animationSpeed))x")
                Slider(value: $animationSpeed, in: 0.1...3.0)
            }
            VStack {
                Text("Intensity: \(String(format: "%.1f", animationIntensity))")
                Slider(value: $animationIntensity, in: 0.1...2.0)
            }
        }
    }
    
    private var gridConfigurationSection: some View {
        Section("Grid Configuration") {
            Stepper("Width: \(width)", value: $width, in: 2...5)
                .onChange(of: width) { _, _ in initializePoints() }
            Stepper("Height: \(height)", value: $height, in: 2...5)
                .onChange(of: height) { _, _ in initializePoints() }
            Toggle("Smooth Colors", isOn: $smoothColors)
            Button(action: randomizePoints) {
                HStack {
                    Image(systemName: "dice")
                    Text("Randomize Points")
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var colorsSection: some View {
        Section("Colors") {
            ForEach(Array(meshPoints.indices), id: \.self) { index in
                ColorPicker("Point \(index + 1)", selection: Binding(
                    get: { meshPoints[index].color },
                    set: { meshPoints[index].color = $0 }
                ))
            }
            Button(action: randomizeColors) {
                HStack {
                    Image(systemName: "dice.fill")
                    Text("Randomize Colors")
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var exportSection: some View {
        Section {
            Button(action: exportToSwiftUI) {
                HStack {
                    Image(systemName: "doc.on.clipboard")
                    Text("Copy SwiftUI Code")
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var notificationOverlay: some View {
        Group {
            if showNotification {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Copied to clipboard!")
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showNotification = false
                    }
                }
            }
        }
    }
    
    private var controlSection: some View {
        Form {
            animationControlsSection
            gridConfigurationSection
            colorsSection
            exportSection
        }
        .formStyle(.grouped)
        .overlay(notificationOverlay)
    }
    
    
    private func exportToSwiftUI() {
        let points = meshPoints.map { point in
            let x = String(format: "%.3f", point.position.x)
            let y = String(format: "%.3f", point.position.y)
            return "            SIMD2<Float>(\(x), \(y))"
        }.joined(separator: ",\n")
        
        let colors = meshPoints.map { point -> String in
            if let components = NSColor(point.color).cgColor.components {
                let r = String(format: "%.3f", components[0])
                let g = String(format: "%.3f", components[1])
                let b = String(format: "%.3f", components[2])
                return "            Color(red: \(r), green: \(g), blue: \(b))"
            }
            return "            Color(.clear)"
        }.joined(separator: ",\n")
        
        let code = """
        MeshGradient(
            width: \(width),
            height: \(height),
            points: [
        \(points)
            ],
            colors: [
        \(colors)
            ],
            smoothsColors: \(smoothColors)
        )
        """
        
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif
        
        showNotification = true
    }

    
    
    
    private func randomizeColors() {
        for index in meshPoints.indices {
            let xPos = meshPoints[index].position.x
            let yPos = meshPoints[index].position.y
            
            // Skip corner points
            let isCorner = (xPos == 0 && yPos == 0) ||
            (xPos == 1 && yPos == 0) ||
            (xPos == 0 && yPos == 1) ||
            (xPos == 1 && yPos == 1)
            
            if !isCorner {
                meshPoints[index].color = Color(
                    red: Double.random(in: 0...1),
                    green: Double.random(in: 0...1),
                    blue: Double.random(in: 0...1)
                )
            }
        }
    }
    
    private func randomizePoints() {
        for index in meshPoints.indices {
            let xPos = meshPoints[index].position.x
            let yPos = meshPoints[index].position.y
            
            let isCorner = (xPos == 0 && yPos == 0) ||
            (xPos == 1 && yPos == 0) ||
            (xPos == 0 && yPos == 1) ||
            (xPos == 1 && yPos == 1)
            
            if !isCorner {
                // Randomize color
                meshPoints[index].color = Color(
                    red: Double.random(in: 0...1),
                    green: Double.random(in: 0...1),
                    blue: Double.random(in: 0...1)
                )
                
                // Randomize position while keeping edge points constrained
                if xPos == 0 || xPos == 1 {
                    // Point is on vertical edge, only randomize Y
                    meshPoints[index].position.y = Float.random(in: 0...1)
                } else if yPos == 0 || yPos == 1 {
                    // Point is on horizontal edge, only randomize X
                    meshPoints[index].position.x = Float.random(in: 0...1)
                } else {
                    // Interior point, randomize both X and Y
                    meshPoints[index].position = SIMD2<Float>(
                        Float.random(in: 0...1),
                        Float.random(in: 0...1)
                    )
                }
            }
        }
    }
    
    
    private func initializePoints() {
        let defaultColors: [Color] = [
            .red, .purple, .indigo,
            .orange, .cyan, .blue,
            .yellow, .green, .mint
        ]
        
        var newPoints: [MeshPoint] = []
        var colorIndex = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let xPos = Float(x) / Float(width - 1)
                let yPos = Float(y) / Float(height - 1)
                let point = MeshPoint(
                    position: SIMD2<Float>(xPos, yPos),
                    color: defaultColors[colorIndex % defaultColors.count]
                )
                newPoints.append(point)
                colorIndex += 1
            }
        }
        
        meshPoints = newPoints
    }
}




struct ContentView: View {
    var body: some View {
        MeshGradientEditor()
    }
}


#Preview {
    ContentView()
}
