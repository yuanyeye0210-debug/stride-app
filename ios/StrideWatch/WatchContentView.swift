import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject private var motion: WatchWorkoutMotionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Circle()
                        .fill(motion.phoneConnected ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(motion.activeWorkoutTitle)
                        .font(.caption2.bold())
                        .lineLimit(1)
                    Spacer()
                    Text(motion.setProgressText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text(motion.currentExercise.nameZH)
                        .font(.headline)
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.center)
                    Text("识别置信度 \(Int((motion.confidence * 100).rounded()))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)

                Text("\(motion.repCount)")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(motion.repCount)))

                if motion.restSecondsLeft > 0 {
                    Label("休息 \(motion.restSecondsLeft)s", systemImage: "timer")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                }

                HStack(spacing: 8) {
                    Button(motion.isRunning ? "停止" : "开始识别") {
                        if motion.isRunning {
                            motion.stopTraining()
                        } else {
                            motion.startTraining()
                        }
                    }
                    .tint(motion.isRunning ? .red : .green)

                    if motion.isRunning {
                        Button("完成组") {
                            motion.completeCurrentSet()
                        }
                        .tint(.blue)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
    }
}
