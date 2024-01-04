//
//  ContentView.swift
//
//  Created by Alex Widua on 01/04/24.
//  Original distortion effect created by Janum Trivedi on 12/30/23.
//

import SwiftUI

#Preview {
    ContentView()
}

struct ContentView: View {
    let screenW = UIScreen.main.bounds.width
    let screenH = UIScreen.main.bounds.height
    
    // ┌───────────────┐
    // │ Shader Values │
    // └───────────────┘
    @State var squeezeCenterX: CGFloat = 0.5
    @State var squeezeProgressX: CGFloat = 0.0
    @State var squeezeProgressY: CGFloat = 0.0
    @State var squeezeTranslationY: CGFloat = 0.0
    
    // ┌────────────────┐
    // │ Misc UI States │
    // └────────────────┘
    @State var imageStackPosition: CGPoint = .zero
    @State var isSqueezed: Bool = false
    
    var body: some View {
        ZStack {
            Color(.black)
                .ignoresSafeArea()
            ZStack {
                // A shader cannot extend beyond the parents layer's size, hence we have to
                // make the parent view larger
                Rectangle()
                    .fill(.black.opacity(0.001))
                    .frame(width: screenW, height: 850)
                ImageGrid()
                    .padding(32.0)
            }
            .modifier(GenieEffect(
                squeezeProgressX: squeezeProgressX,
                squeezeProgressY: squeezeProgressY,
                squeezeTranslationY: squeezeTranslationY,
                squeezeCenterX: squeezeCenterX
            ))
            
            // Blurry black area at the bottom to make the squeezed layer vanish (TODO: Make this part of the shader?)
            Rectangle()
                .fill(.black.opacity(1.0))
                .frame(height: 350)
                .offset(y: 450)
                .scaleEffect(x: 2)
                .blur(radius: 32)
            
            // Image stack
            RoundedRectangle(cornerRadius: 32.0)
                .fill(.ultraThinMaterial)
                .frame(width: 96, height: 96)
                .overlay {
                    ImageGrid(spacing: 4.0)
                        .padding(16.0)
                }
                .scaleEffect(x: isSqueezed ? 1.0 : 0.5, y: isSqueezed ? 1.0 : 0.5 )
                .opacity(isSqueezed ? 1.0 : 0.0)
                .position(imageStackPosition)
            
        }
        .statusBar(hidden: true)
        .ignoresSafeArea()
        .gesture(
            DragGesture(minimumDistance: 0.0)
                .onChanged { value in
                    let x = value.location.x
                    let y = value.location.y
                    
                    let clampedY = max((screenH - 150), y)
                    
                    // Set & animate the little image stack that appears at the thumb
                    if(!isSqueezed) {
                        imageStackPosition = CGPoint(x: x, y: clampedY)
                    }
                    withAnimation(.spring()) {
                        imageStackPosition = CGPoint(x: x, y: clampedY)
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.26)) {
                        isSqueezed = true
                    }
                    
                    // The squeeze center value isn't animated because it messes with the squeeze effect.
                    let normalizedX = mapRange(value.location.x, 0.0, screenW, 0.0, 1.0)
                    squeezeCenterX = normalizedX
                    
                    // The squeeze and stretch values use time-based animations instead of springs because springs result in janky animations (this is probably a flaw wih the shader code).
                    // TODO: Fix shader implementation or try use Wave?
                    withAnimation(.easeInOut(duration: 0.6)) {
                        squeezeProgressX = 1.0
                        squeezeProgressY = 1.0
                    }
                    
                    // Delay the y translation slightly to give the layer some time to stretch & squeeze. This gives the animation more 'mass' and physicality...
                    withAnimation(.easeInOut(duration: 0.5).delay(0.1666)) {
                        squeezeTranslationY = 1.0
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.0)) {
                        isSqueezed = false
                    }
                    
                    withAnimation(.spring(response: 0.7, dampingFraction: 1.1).delay(0.0)) {
                        squeezeProgressX = 0.0
                        squeezeProgressY = 0.0
                        squeezeTranslationY = 0.0
                    }
                }
        )
        // Haptics stuff
        .onChange(of: isSqueezed) { _, squeezed in
            let softFeedback = UIImpactFeedbackGenerator(style: .soft)
            softFeedback.impactOccurred()
            handleHapticFeedback(squeezed)
        }
    }
    
    func mapRange(_ value: CGFloat, _ inputMin: CGFloat, _ inputMax: CGFloat, _ outputMin: CGFloat, _ outputMax: CGFloat) -> CGFloat {
        return outputMin + (outputMax - outputMin) * (value - inputMin) / (inputMax - inputMin)
    }
    
    // Fire haptic feedback only if genie animation finishes
    @State private var hapticDispatch: DispatchWorkItem?
    private func handleHapticFeedback(_ squeezed: Bool) {
        
        let triggerHapticsAfterMs = 0.275
        hapticDispatch?.cancel()
        if squeezed {
            hapticDispatch = DispatchWorkItem {
                let mediumFeedback = UIImpactFeedbackGenerator(style: .rigid)
                mediumFeedback.impactOccurred()
            }
            if let hapticDispatch = hapticDispatch {
                DispatchQueue.main.asyncAfter(deadline: .now() + triggerHapticsAfterMs, execute: hapticDispatch)
            }
        }
    }
}

// Wrap the shader inside a ViewModifier to make the shader values animateable
struct GenieEffect: ViewModifier, Animatable {
    
    // Ref: https://www.hackingwithswift.com/books/ios-swiftui/animating-complex-shapes-with-animatablepair
    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get {
            AnimatableData(AnimatablePair(squeezeProgressX, squeezeProgressY), squeezeTranslationY)
        }
        set {
            squeezeProgressX = newValue.first.first
            squeezeProgressY = newValue.first.second
            squeezeTranslationY = newValue.second
        }
    }
    
    var squeezeCenterX: CGFloat
    var squeezeProgressX: CGFloat
    var squeezeProgressY: CGFloat
    var squeezeTranslationY: CGFloat
    
    init(squeezeProgressX: CGFloat, squeezeProgressY: CGFloat, squeezeTranslationY: CGFloat, squeezeCenterX: CGFloat) {
        self.squeezeProgressX = squeezeProgressX
        self.squeezeProgressY = squeezeProgressY
        self.squeezeTranslationY = squeezeTranslationY
        self.squeezeCenterX = squeezeCenterX
    }
    
    func shader() -> Shader {
        Shader(function: .init(library: .default, name: "distortion"), arguments: [
            .boundingRect,
            .float(squeezeCenterX),
            .float(squeezeProgressX),
            .float(squeezeProgressY),
            .float(squeezeTranslationY)
        ])
    }
    
    func body(content: Content) -> some View {
        content
            .distortionEffect(shader(), maxSampleOffset: CGSize(width: 500, height: 500))
    }
}

struct ImageGrid: View {
    var spacing: CGFloat = 8.0
    var body: some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                Image("image-credits-arthur-humeau")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                Image("image-credits-keith-hardy")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            HStack(spacing: spacing) {
                Image("image-credits-nikola-mirkovic")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                Image("image-credits-joakim-nadell")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}
