# Apple Watch 6 轴 IMU 动作识别模型

本目录提供与 iOS/watchOS 端侧 `WatchMotionEngine` 完全对称的轻量级机器学习训练脚本与权重导出流程。

## 支持识别的 11 类动作标签
1. `barbell-bench-press`（杠铃平板卧推）
2. `dumbbell-bicep-curl`（站姿哑铃弯举）
3. `barbell-back-squat`（杠铃颈后深蹲）
4. `barbell-deadlift`（杠铃传统硬拉）
5. `pull-up`（宽距引体向上）
6. `seated-dumbbell-shoulder-press`（坐姿哑铃推举）
7. `lateral-raise`（哑铃侧平举）
8. `barbell-row`（俯身杠铃划船）
9. `push-up`（标准俯卧撑）
10. `rope-tricep-pushdown`（绳索双头绳三头下压）
11. `idle`（静息/日常走动）

## 特征工程（30 维）
对每 2.0 秒（`50Hz` = `100` 帧）的 `[ax, ay, az, gx, gy, gz]` 窗口提取：
- 6 通道各自的 `mean`, `std`, `peak-to-peak`, `rms`（共 24 维）
- 3 轴加速度方差能量占比（3 维）
- 3 轴陀螺仪角速度方差能量占比（3 维）

## 复现训练与个人实采数据微调

```bash
# 默认训练并导出至 ios/Stride/Resources/watch_exercise_classifier_v1.json
uv run --with numpy python ml/watch_exercise_model/train_watch_imu_model.py

# 若有实采手表/手机标注 CSV（列头：label,ax,ay,az,gx,gy,gz），可追加微调：
uv run --with numpy python ml/watch_exercise_model/train_watch_imu_model.py --user-csv my_sets.csv
```
