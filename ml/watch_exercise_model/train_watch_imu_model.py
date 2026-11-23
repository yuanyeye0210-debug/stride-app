#!/usr/bin/env python3
"""
Apple Watch 6 轴 IMU（50Hz）动作识别轻量神经网络训练与导出脚本。

模型结构：
- 输入：100 帧（2.0 秒 @ 50Hz）的 6 轴数据 (ax, ay, az, gx, gy, gz)
- 特征：30 维物理特征（6 通道各自 mean/std/p2p/rms 共 24 维 + 3 轴动态加速度能量占比 + 3 轴陀螺仪能量占比）
- 网络：Z-Score 标准化 -> Linear(30 -> 32) -> ReLU -> Linear(32 -> 11) -> Softmax
- 输出：f:/vebcoding/stride-app/ios/Stride/Resources/watch_exercise_classifier_v1.json

支持传入 --user-csv <path> 追加个人实采标注数据进行微调。
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np

LABELS: List[str] = [
    "barbell-bench-press",
    "dumbbell-bicep-curl",
    "barbell-back-squat",
    "barbell-deadlift",
    "pull-up",
    "seated-dumbbell-shoulder-press",
    "lateral-raise",
    "barbell-row",
    "push-up",
    "rope-tricep-pushdown",
    "idle",
]

SAMPLE_RATE_HZ = 50
WINDOW_SIZE = 100
FEATURE_DIM = 30
HIDDEN_DIM = 32

DEFAULT_OUTPUT = (
    Path(__file__).resolve().parents[2]
    / "ios"
    / "Stride"
    / "Resources"
    / "watch_exercise_classifier_v1.json"
)


def extract_features(window: np.ndarray) -> np.ndarray:
    """
    从 (N, 6) 窗口提取 30 维特征；与 Swift 端 WatchMotionFeatureExtractor 逐项严格一致。
    通道顺序：[ax, ay, az, gx, gy, gz]
    """
    means = np.mean(window, axis=0)
    stds = np.std(window, axis=0, ddof=0)
    p2p = np.max(window, axis=0) - np.min(window, axis=0)
    rms = np.sqrt(np.mean(window * window, axis=0))

    stats_24 = np.empty(24, dtype=np.float64)
    for ch in range(6):
        stats_24[ch * 4 + 0] = means[ch]
        stats_24[ch * 4 + 1] = stds[ch]
        stats_24[ch * 4 + 2] = p2p[ch]
        stats_24[ch * 4 + 3] = rms[ch]

    acc_var = np.var(window[:, 0:3], axis=0, ddof=0)
    acc_total = float(np.sum(acc_var)) + 1e-6
    acc_ratios = acc_var / acc_total

    gyro_var = np.var(window[:, 3:6], axis=0, ddof=0)
    gyro_total = float(np.sum(gyro_var)) + 1e-6
    gyro_ratios = gyro_var / gyro_total

    return np.concatenate([stats_24, acc_ratios, gyro_ratios], axis=0)


def synthesize_window(
    label: str,
    rng: np.random.Generator,
    duration_sec: float = 2.0,
) -> np.ndarray:
    """按腕部 IMU 生物力学先验合成一条 100×6（50Hz）的训练窗口。"""
    n = WINDOW_SIZE
    t = np.linspace(0.0, duration_sec, n, endpoint=False)
    phase = rng.uniform(0.0, 2.0 * np.pi)
    period = rng.uniform(1.45, 3.1)
    omega = 2.0 * np.pi / period
    s = np.sin(omega * t + phase)
    c = np.cos(omega * t + phase)
    hand_sign = rng.choice([-1.0, 1.0])
    tilt = rng.normal(0.0, 0.08, size=3)

    ax = np.zeros(n)
    ay = np.zeros(n)
    az = np.zeros(n)
    gx = np.zeros(n)
    gy = np.zeros(n)
    gz = np.zeros(n)

    if label == "barbell-bench-press":
        # 仰卧垂直上推：重力持续压在 -X，沿 X 轴对称推起/下放加速度，几乎无旋转
        ax = -0.92 + 0.42 * s + tilt[0]
        ay = 0.08 * hand_sign + 0.09 * s + tilt[1]
        az = 0.32 + 0.14 * c + tilt[2]
        gx = 0.18 * c * hand_sign
        gy = 0.24 * c
        gz = 0.12 * s
    elif label == "dumbbell-bicep-curl":
        # 站姿哑铃弯举：重力从 -X 动态转向 +Z，强绕 Y 轴角速度，伴随掌心旋外
        angle = 0.95 * (0.5 * (1.0 + s))
        ax = -0.95 * np.cos(angle) + 0.22 * s + tilt[0]
        ay = 0.15 * hand_sign + 0.14 * c + tilt[1]
        az = 0.90 * np.sin(angle) + 0.24 * c + tilt[2]
        gx = 0.55 * hand_sign * c
        gy = 2.35 * c
        gz = 0.35 * s
    elif label == "barbell-back-squat":
        # 杠铃深蹲：双手肩上固定握杆斜向，身体上下整体加减速，腕角速度极低
        ax = -0.66 + 0.36 * s + tilt[0]
        ay = 0.22 * hand_sign + 0.08 * s + tilt[1]
        az = 0.70 + 0.32 * s + tilt[2]
        gx = 0.16 * c
        gy = 0.22 * c
        gz = 0.14 * s
    elif label == "barbell-deadlift":
        # 传统硬拉：双臂始终垂直下垂，重力稳定落在 +X，垂直脉冲，角速度低
        ax = 0.96 + 0.44 * s + tilt[0]
        ay = 0.12 * hand_sign + 0.10 * c + tilt[1]
        az = 0.18 + 0.16 * s + tilt[2]
        gx = 0.18 * s
        gy = 0.26 * c
        gz = 0.15 * c
    elif label == "pull-up":
        # 引体向上：悬垂头顶抓杠，重力在 -X，拉起时前臂微摆与明显 Y 轴摆动，周期略长
        ax = -0.90 + 0.30 * s + tilt[0]
        ay = -0.35 * hand_sign + 0.22 * s + tilt[1]
        az = -0.18 + 0.28 * c + tilt[2]
        gx = 0.48 * c
        gy = 0.95 * c
        gz = 0.52 * hand_sign * s
    elif label == "seated-dumbbell-shoulder-press":
        # 坐姿推举：高位肩侧至过头顶，-X 与 Y 弧线耦合 + 明显双轴旋转
        ax = -0.78 + 0.48 * s + tilt[0]
        ay = 0.42 * hand_sign + 0.32 * c + tilt[1]
        az = 0.26 + 0.22 * s + tilt[2]
        gx = 1.05 * hand_sign * c
        gy = 0.65 * s
        gz = 0.90 * c
    elif label == "lateral-raise":
        # 哑铃侧平举：垂直下垂 (+X) 外展到肩平 (+Y/+Z)，强烈绕 X/Z 滚动角速度
        lift = 0.5 * (1.0 + s)
        ax = 0.92 * (1.0 - 0.85 * lift) + tilt[0]
        ay = 0.85 * hand_sign * lift + 0.18 * s + tilt[1]
        az = 0.42 * lift + 0.16 * c + tilt[2]
        gx = 1.95 * hand_sign * c
        gy = 0.45 * s
        gz = 1.15 * c
    elif label == "barbell-row":
        # 俯身划船：手臂由垂直 (+X) 斜拉向髋部，X/Z 联动 + 中等单轴摇摆
        ax = 0.82 + 0.38 * s + tilt[0]
        ay = 0.14 * hand_sign + 0.14 * c + tilt[1]
        az = 0.48 + 0.36 * s + tilt[2]
        gx = 0.35 * s
        gy = 1.35 * c
        gz = 0.38 * s
    elif label == "push-up":
        # 标准俯卧撑：掌撑地背伸 90°，重力强落 +Z、次落 -X，纯垂直升降几乎无转动
        ax = -0.44 + 0.22 * s + tilt[0]
        ay = 0.06 * hand_sign + 0.08 * c + tilt[1]
        az = 0.86 + 0.42 * s + tilt[2]
        gx = 0.16 * c
        gy = 0.20 * s
        gz = 0.12 * c
    elif label == "rope-tricep-pushdown":
        # 绳索三头下压：屈肘水平 (+Z) 下压至伸直 (+X) 伴末端分绳外旋 (-gy/gz)
        ext = 0.5 * (1.0 - s)
        ax = 0.18 + 0.78 * ext + 0.18 * s + tilt[0]
        ay = -0.18 * hand_sign + 0.22 * ext + tilt[1]
        az = 0.88 * (1.0 - 0.82 * ext) + 0.16 * c + tilt[2]
        gx = 0.42 * s
        gy = -1.90 * c
        gz = 0.92 * hand_sign * s
    else:  # idle
        mode = int(rng.integers(0, 3))
        if mode == 0:  # 静坐看手机/休息
            g = rng.normal(0.0, 1.0, size=3)
            g = g / (np.linalg.norm(g) + 1e-6)
            ax = np.full(n, g[0])
            ay = np.full(n, g[1])
            az = np.full(n, g[2])
        elif mode == 1:  # 日常慢走摆臂
            ax = 0.75 + 0.12 * np.sin(5.2 * t + phase)
            ay = 0.35 + 0.10 * np.cos(5.2 * t + phase)
            az = 0.25 + 0.08 * np.sin(2.6 * t + phase)
            gx = 0.65 * np.cos(5.2 * t + phase)
            gy = 0.55 * np.sin(5.2 * t + phase)
            gz = 0.45 * np.cos(2.6 * t + phase)
        else:  # 调整器械/拿水瓶杂乱微动
            ax = rng.uniform(-0.8, 0.8) + 0.08 * np.sin(3.3 * t + phase)
            ay = rng.uniform(-0.6, 0.6) + 0.09 * np.cos(4.1 * t + phase)
            az = rng.uniform(-0.6, 0.6) + 0.08 * np.sin(2.1 * t)
            gx = 0.35 * np.sin(3.7 * t)
            gy = 0.35 * np.cos(2.9 * t)
            gz = 0.30 * np.sin(4.5 * t)

    window = np.stack([ax, ay, az, gx, gy, gz], axis=1)
    # 添加传感器测量噪声与轻微通道增益漂移
    gain = rng.uniform(0.92, 1.08, size=(1, 6))
    noise_std = np.array([0.045, 0.045, 0.045, 0.08, 0.08, 0.08])
    window = window * gain + rng.normal(0.0, noise_std, size=window.shape)
    return window


def load_user_csv(csv_path: Path) -> Tuple[np.ndarray, np.ndarray]:
    """
    可选加载用户实采标注 CSV（列: label, ax, ay, az, gx, gy, gz）。
    按滑窗 100 帧（步长 50）切分并提取特征。
    """
    by_label: Dict[str, List[List[float]]] = {}
    with csv_path.open("r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            lbl = row["label"].strip()
            if lbl not in LABELS:
                continue
            by_label.setdefault(lbl, []).append(
                [
                    float(row["ax"]),
                    float(row["ay"]),
                    float(row["az"]),
                    float(row["gx"]),
                    float(row["gy"]),
                    float(row["gz"]),
                ]
            )
    feats, ys = [], []
    label_to_idx = {l: i for i, l in enumerate(LABELS)}
    for lbl, rows in by_label.items():
        arr = np.asarray(rows, dtype=np.float64)
        for start in range(0, max(0, len(arr) - WINDOW_SIZE + 1), 50):
            win = arr[start : start + WINDOW_SIZE]
            feats.append(extract_features(win))
            ys.append(label_to_idx[lbl])
    if not feats:
        return np.zeros((0, FEATURE_DIM)), np.zeros((0,), dtype=np.int64)
    return np.vstack(feats), np.asarray(ys, dtype=np.int64)


def train_mlp(
    X_train: np.ndarray,
    y_train: np.ndarray,
    X_test: np.ndarray,
    y_test: np.ndarray,
    seed: int = 42,
) -> Tuple[dict, float]:
    mean = np.mean(X_train, axis=0)
    std = np.std(X_train, axis=0) + 1e-6

    Xn_train = (X_train - mean) / std
    Xn_test = (X_test - mean) / std

    rng = np.random.default_rng(seed)
    num_classes = len(LABELS)
    w1 = rng.normal(0.0, np.sqrt(2.0 / FEATURE_DIM), size=(FEATURE_DIM, HIDDEN_DIM))
    b1 = np.zeros(HIDDEN_DIM)
    w2 = rng.normal(0.0, np.sqrt(2.0 / HIDDEN_DIM), size=(HIDDEN_DIM, num_classes))
    b2 = np.zeros(num_classes)

    # Adam 状态
    lr = 0.008
    l2 = 1e-4
    params = [w1, b1, w2, b2]
    m = [np.zeros_like(p) for p in params]
    v = [np.zeros_like(p) for p in params]
    beta1, beta2, eps = 0.9, 0.999, 1e-8

    batch_size = 128
    n_samples = len(Xn_train)
    step = 0

    for epoch in range(1, 91):
        perm = rng.permutation(n_samples)
        for start in range(0, n_samples, batch_size):
            idx = perm[start : start + batch_size]
            xb = Xn_train[idx]
            yb = y_train[idx]
            bs = len(xb)

            # Forward
            z1 = xb @ params[0] + params[1]
            h1 = np.maximum(0.0, z1)
            logits = h1 @ params[2] + params[3]
            logits -= np.max(logits, axis=1, keepdims=True)
            exp_l = np.exp(logits)
            probs = exp_l / np.sum(exp_l, axis=1, keepdims=True)

            # Backward
            dlogits = probs.copy()
            dlogits[np.arange(bs), yb] -= 1.0
            dlogits /= bs

            gw2 = h1.T @ dlogits + l2 * params[2]
            gb2 = np.sum(dlogits, axis=0)
            dh1 = dlogits @ params[2].T
            dz1 = dh1 * (z1 > 0.0)
            gw1 = xb.T @ dz1 + l2 * params[0]
            gb1 = np.sum(dz1, axis=0)

            step += 1
            for pi, g in enumerate([gw1, gb1, gw2, gb2]):
                m[pi] = beta1 * m[pi] + (1.0 - beta1) * g
                v[pi] = beta2 * v[pi] + (1.0 - beta2) * (g * g)
                m_hat = m[pi] / (1.0 - beta1**step)
                v_hat = v[pi] / (1.0 - beta2**step)
                params[pi] -= lr * m_hat / (np.sqrt(v_hat) + eps)

    # 评估准确率
    z1_t = Xn_test @ params[0] + params[1]
    h1_t = np.maximum(0.0, z1_t)
    logits_t = h1_t @ params[2] + params[3]
    preds = np.argmax(logits_t, axis=1)
    acc = float(np.mean(preds == y_test))

    model_dict = {
        "version": 1,
        "sampleRateHz": SAMPLE_RATE_HZ,
        "windowSize": WINDOW_SIZE,
        "featureDim": FEATURE_DIM,
        "hiddenDim": HIDDEN_DIM,
        "labels": LABELS,
        "mean": [round(float(x), 6) for x in mean],
        "std": [round(float(x), 6) for x in std],
        "w1": [[round(float(v), 6) for v in row] for row in params[0]],
        "b1": [round(float(x), 6) for x in params[1]],
        "w2": [[round(float(v), 6) for v in row] for row in params[2]],
        "b2": [round(float(x), 6) for x in params[3]],
        "testAccuracy": round(acc, 4),
    }
    return model_dict, acc


def main() -> None:
    parser = argparse.ArgumentParser(description="训练 Apple Watch 6 轴动作识别模型")
    parser.add_argument("--samples-per-class", type=int, default=400)
    parser.add_argument("--user-csv", type=Path, default=None)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    rng = np.random.default_rng(42)
    X_list, y_list = [], []
    for idx, label in enumerate(LABELS):
        for _ in range(args.samples_per_class):
            win = synthesize_window(label, rng)
            X_list.append(extract_features(win))
            y_list.append(idx)

    X = np.vstack(X_list)
    y = np.asarray(y_list, dtype=np.int64)

    if args.user_csv and args.user_csv.exists():
        uX, uy = load_user_csv(args.user_csv)
        if len(uX) > 0:
            X = np.vstack([X, uX])
            y = np.concatenate([y, uy])
            print(f"已融合个人实采窗口样本: {len(uX)} 条")

    # 80/20 分层随机划分
    perm = rng.permutation(len(X))
    split = int(len(X) * 0.8)
    train_idx, test_idx = perm[:split], perm[split:]
    model_dict, acc = train_mlp(X[train_idx], y[train_idx], X[test_idx], y[test_idx])

    print(f"测试集准确率 (N={len(test_idx)}): {acc * 100:.2f}%")
    if acc < 0.95:
        raise RuntimeError(f"测试集准确率 {acc:.4f} 低于 95% 阈值")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(model_dict, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"已导出端侧模型权重 -> {args.output} ({args.output.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
