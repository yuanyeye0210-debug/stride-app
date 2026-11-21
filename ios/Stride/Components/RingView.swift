import SwiftUI

struct RingView: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var colors: [Color] = [Palette.green, Color(hex: 0x2AD4C8)]
    var track: Color = Palette.cardHigh

    @State private var appeared = false

    private var clampedProgress: Double {
        appeared ? max(0.001, min(1, progress)) : 0.001
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(colors: colors + [colors.first ?? Palette.green], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.72, dampingFraction: 0.84), value: clampedProgress)
                .animation(.spring(response: 0.55, dampingFraction: 0.84), value: progress)
        }
        .onAppear {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.84)) {
                appeared = true
            }
        }
    }
}

struct RingStat: View {
    let progress: Double
    let value: String
    let unit: String
    let caption: String
    var colors: [Color] = [Palette.green, Color(hex: 0x2AD4C8)]
    var size: CGFloat = 128

    var body: some View {
        ZStack {
            RingView(progress: progress, lineWidth: 13, colors: colors)
            VStack(spacing: 1) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .numericRoll(value: value)
                Text(unit)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textDim)
                Text(caption)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.textFaint)
                    .padding(.top, 1)
            }
        }
        .frame(width: size, height: size)
    }
}

struct BarProgress: View {
    var progress: Double
    var color: Color = Palette.green
    var height: CGFloat = 6

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let target = appeared ? min(1, max(0, progress)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.cardHigh)
                Capsule()
                    .fill(color)
                    .frame(width: max(3, geo.size.width * target))
                    .animation(.spring(response: 0.65, dampingFraction: 0.84), value: target)
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: progress)
            }
        }
        .frame(height: height)
        .onAppear { appeared = true }
    }
}

struct MacroBar: View {
    let title: String
    let current: Double
    let target: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textDim)
                Spacer()
                Text("\(Int(current))/\(Int(target))g")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            BarProgress(progress: target > 0 ? current / target : 0, color: color, height: 5)
        }
    }
}
