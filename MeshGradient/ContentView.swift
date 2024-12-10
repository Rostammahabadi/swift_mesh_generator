//
//  ContentView.swift
//  MeshGradient
//
//  Created by Rostam on 12/9/24.
//

import SwiftUI


enum AnimationType: String, CaseIterable {
    case wave = "Wave"
    case rotate = "Rotate"
    case pulse = "Pulse"
    case bounce = "Bounce"
    case spiral = "Spiral"
}

struct MeshGradientEditor: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var width: Int = 3
    @State private var height: Int = 3
    @State private var smoothColors: Bool = true
    @State private var isAnimating: Bool = false
    @State private var selectedAnimationType: AnimationType = .wave
    @State private var animationSpeed: Double = 1.0
    @State private var animationIntensity: Double = 1.0
    @State private var selectedColors: [Color] = [
        .red, .purple, .indigo,
        .orange, .cyan, .blue,
        .yellow, .green, .mint
    ]
    
    private var points: [SIMD2<Float>] {
        var result: [SIMD2<Float>] = []
        let timeInterval = Date().timeIntervalSince1970 * animationSpeed
        
        for y in 0..<height {
            for x in 0..<width {
                let xPos = Float(x) / Float(width - 1)
                let yPos = Float(y) / Float(height - 1)
                
                var offsetX: Float = 0
                var offsetY: Float = 0
                
                if isAnimating {
                    let intensity = Float(animationIntensity) * 0.1
                    
                    switch selectedAnimationType {
                    case .wave:
                        offsetX = Float(sin(timeInterval + Double(y) * 0.5)) * intensity
                        offsetY = Float(cos(timeInterval + Double(x) * 0.5)) * intensity
                    case .pulse:
                        let scale = Float(1.0 + sin(timeInterval) * Double(intensity))
                        offsetX = (xPos - 0.5) * (scale - 1) * 2
                        offsetY = (yPos - 0.5) * (scale - 1) * 2
                    case .bounce:
                        offsetY = Float(abs(sin(timeInterval + Double(x) * 0.3))) * intensity * 2
                    case .rotate:
                        // Calculate distance from center
                        let centerX: Float = 0.5
                        let centerY: Float = 0.5
                        let dx = xPos - centerX
                        let dy = yPos - centerY
                        let angle = Float(timeInterval)
                        
                        // Apply circular rotation around center
                        offsetX = (cos(angle) * dx - sin(angle) * dy) * 2
                        offsetY = (sin(angle) * dx + cos(angle) * dy) * 2
                        
                    case .spiral:
                        // Calculate distance from center
                        let centerX: Float = 0.5
                        let centerY: Float = 0.5
                        let dx = xPos - centerX
                        let dy = yPos - centerY
                        let distance = sqrt(dx * dx + dy * dy)
                        
                        // Create spiral effect by combining rotation with inward/outward motion
                        let angle = Float(timeInterval) + distance * 10
                        let spiralScale = 1.0 + sin(timeInterval) * Double(intensity)
                        offsetX = (cos(angle) * dx - sin(angle) * dy) * Float(spiralScale)
                        offsetY = (sin(angle) * dx + cos(angle) * dy) * Float(spiralScale)
                        
                    }
                }
                
                result.append(SIMD2<Float>(xPos + offsetX, yPos + offsetY))
            }
        }
        return result
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
    }
    
    private var previewSection: some View {
        TimelineView(.animation) { timeline in
            MeshGradient(
                width: width,
                height: height,
                points: points,
                colors: selectedColors,
                smoothsColors: smoothColors
            )
            .frame(minHeight: 300)
            .cornerRadius(16)
        }
    }
    
    private var controlSection: some View {
        Form {
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
            
            Section("Grid Configuration") {
                Stepper("Width: \(width)", value: $width, in: 2...5)
                    .onChange(of: width) { _, _ in adjustColors() }
                Stepper("Height: \(height)", value: $height, in: 2...5)
                    .onChange(of: height) { _, _ in adjustColors() }
                Toggle("Smooth Colors", isOn: $smoothColors)
            }
            
            Section("Colors") {
                ForEach(0..<selectedColors.count, id: \.self) { index in
                    ColorPicker("Color \(index + 1)", selection: $selectedColors[index])
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func adjustColors() {
        let requiredColors = width * height
        if selectedColors.count > requiredColors {
            selectedColors = Array(selectedColors.prefix(requiredColors))
        } else if selectedColors.count < requiredColors {
            let additionalColors = Array(repeating: Color.gray, count: requiredColors - selectedColors.count)
            selectedColors.append(contentsOf: additionalColors)
        }
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
