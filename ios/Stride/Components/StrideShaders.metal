#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// 1. 物理阻尼水波纹扩散 Shader（用于饮水打卡、点击涟漪反馈）
[[ stitchable ]] half4 strideRipple(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float elapsed,
    float amplitude,
    float frequency,
    float decay
) {
    if (elapsed <= 0.0f) {
        return layer.sample(position);
    }

    float2 delta = position - origin;
    float dist = max(length(delta), 0.001f);
    float speed = 260.0f;
    float waveFront = elapsed * speed;
    float delay = dist / speed;
    float localTime = elapsed - delay;

    if (localTime <= 0.0f || dist > waveFront + 60.0f) {
        return layer.sample(position);
    }

    float rippleAmount = amplitude * sin(frequency * localTime) * exp(-decay * localTime);
    float attenuation = exp(-0.006f * dist);
    float disp = rippleAmount * attenuation;

    float2 dir = delta / dist;
    half4 color = layer.sample(position + dir * disp);

    // 在波峰处叠加柔和冰蓝高光
    half highlight = half(max(0.0f, disp / max(amplitude, 0.001f)) * 0.22f * attenuation);
    color.rgb += half3(0.32h, 0.70h, 1.0h) * highlight * color.a;
    return color;
}

// 2. 流动多色极光网格 Shader（用于 AI 教练光幕、Stride Intelligence、AI 悬浮球）
[[ stitchable ]] half4 strideAuroraFlow(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    half4 colorA,
    half4 colorB,
    half4 colorC
) {
    if (currentColor.a <= 0.005h) {
        return currentColor;
    }

    float2 safeSize = max(size, float2(1.0f, 1.0f));
    float2 uv = position / safeSize;

    float w1 = sin(uv.x * 3.1f + time * 1.15f + cos(uv.y * 2.4f - time * 0.7f));
    float w2 = cos(uv.y * 3.6f - time * 0.9f + sin(uv.x * 2.8f + time * 0.8f));
    float mixAB = clamp(0.5f + 0.5f * w1, 0.0f, 1.0f);
    float mixC = clamp(0.5f + 0.5f * w2, 0.0f, 1.0f);

    half4 blended = mix(colorA, colorB, half(mixAB));
    blended = mix(blended, colorC, half(mixC * 0.55f));

    // 融合原底色亮度并保持优雅暗夜透明度
    half3 finalRGB = mix(currentColor.rgb, blended.rgb, 0.72h);
    return half4(finalRGB * currentColor.a, currentColor.a);
}

// 3. 金属钛金流光扫过 Shader（用于主 CTA 按钮、成就卡片、高光胶囊）
[[ stitchable ]] half4 strideShimmerSweep(
    float2 position,
    half4 currentColor,
    float2 size,
    float phase
) {
    if (currentColor.a <= 0.01h) {
        return currentColor;
    }

    float2 safeSize = max(size, float2(1.0f, 1.0f));
    float2 uv = position / safeSize;

    // 倾斜 25 度对角扫光带
    float diag = uv.x * 0.85f + uv.y * 0.35f;
    float dist = abs(diag - phase);
    float band = smoothstep(0.24f, 0.0f, dist);

    half3 glow = half3(1.0h, 0.96h, 0.86h) * half(band * 0.28f);
    half3 rgb = clamp(currentColor.rgb + glow * currentColor.a, half3(0.0h), half3(1.0h));
    return half4(rgb, currentColor.a);
}

// 4. 视觉识别激光扫描光束 Shader（用于拍餐识别、条形码扫码框）
[[ stitchable ]] half4 strideScanBeam(
    float2 position,
    half4 currentColor,
    float2 size,
    float progress,
    half4 beamColor
) {
    if (currentColor.a <= 0.01h) {
        return currentColor;
    }

    float2 safeSize = max(size, float2(1.0f, 1.0f));
    float yNorm = position.y / safeSize.y;
    float d = abs(yNorm - progress);

    float core = smoothstep(0.032f, 0.0f, d);
    float trail = smoothstep(0.16f, 0.0f, d) * 0.38f;
    half intensity = half(core + trail);

    half3 rgb = clamp(currentColor.rgb + beamColor.rgb * intensity * currentColor.a, half3(0.0h), half3(1.0h));
    return half4(rgb, currentColor.a);
}
