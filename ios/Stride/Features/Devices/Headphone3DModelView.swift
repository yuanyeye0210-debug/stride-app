import SwiftUI
import SceneKit

/// 基于 SceneKit PBR 材质渲染的 6 款耳机高精度 3D 模型展台：
/// 支持手指 360° 自由拖动旋转，并在监测激活时跟随真实头部俯仰/偏航/侧倾实时转动。
struct Headphone3DModelView: UIViewRepresentable {
    var model: HeadphoneModelKind
    var maxColor: AirPodsMaxColor
    var pitchDeg: Double
    var yawDeg: Double
    var rollDeg: Double
    var isHeadDownWarning: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X

        let scene = SCNScene()
        view.scene = scene

        // 透视主相机
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 38
        camera.zNear = 0.05
        camera.zFar = 30
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0.22, 3.35)
        cameraNode.look(at: SCNVector3(0, 0.02, 0))
        scene.rootNode.addChildNode(cameraNode)

        // 摄影棚三点照明
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 1150
        keyLight.light?.color = UIColor(white: 1.0, alpha: 1.0)
        keyLight.position = SCNVector3(2.2, 3.2, 3.5)
        keyLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLight)

        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .omni
        rimLight.light?.intensity = 650
        rimLight.light?.color = UIColor(red: 0.45, green: 0.72, blue: 1.0, alpha: 1.0)
        rimLight.position = SCNVector3(-2.6, 1.4, -2.0)
        scene.rootNode.addChildNode(rimLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .ambient
        fillLight.light?.intensity = 420
        fillLight.light?.color = UIColor(white: 0.88, alpha: 1.0)
        scene.rootNode.addChildNode(fillLight)

        // 底部科技悬浮环底座
        let baseRing = SCNTorus(ringRadius: 0.92, pipeRadius: 0.012)
        let ringMat = SCNMaterial()
        ringMat.lightingModel = .physicallyBased
        ringMat.diffuse.contents = UIColor(red: 0.25, green: 0.83, blue: 0.48, alpha: 0.45)
        ringMat.emission.contents = UIColor(red: 0.20, green: 0.78, blue: 0.44, alpha: 0.35)
        baseRing.materials = [ringMat]
        let baseNode = SCNNode(geometry: baseRing)
        baseNode.position = SCNVector3(0, -0.92, 0)
        scene.rootNode.addChildNode(baseNode)
        context.coordinator.ringMaterial = ringMat

        // 耳机模型根节点（挂接具体模型与随动旋转）
        let headsetRoot = SCNNode()
        scene.rootNode.addChildNode(headsetRoot)
        context.coordinator.headsetRoot = headsetRoot

        // 轻微空闲呼吸动画节点包
        let modelContainer = SCNNode()
        headsetRoot.addChildNode(modelContainer)
        context.coordinator.modelContainer = modelContainer

        rebuildGeometry(in: modelContainer, model: model, maxColor: maxColor)
        context.coordinator.lastModel = model
        context.coordinator.lastMaxColor = maxColor

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let coord = context.coordinator
        if coord.lastModel != model || coord.lastMaxColor != maxColor {
            if let container = coord.modelContainer {
                rebuildGeometry(in: container, model: model, maxColor: maxColor)
            }
            coord.lastModel = model
            coord.lastMaxColor = maxColor
        }

        // 底座氛围灯随低头告警变色
        if let ringMat = coord.ringMaterial {
            let color: UIColor = isHeadDownWarning
                ? UIColor(red: 1.0, green: 0.42, blue: 0.28, alpha: 0.85)
                : UIColor(red: 0.25, green: 0.83, blue: 0.48, alpha: 0.55)
            ringMat.diffuse.contents = color
            ringMat.emission.contents = color
        }

        // 平滑同步头部真实三轴倾角（低头前倾 +pitch -> 绕 X 轴微前倾）
        if let root = coord.headsetRoot {
            let clampedPitch = Float(max(-48.0, min(48.0, pitchDeg)) * .pi / 180.0)
            let clampedYaw = Float(max(-65.0, min(65.0, yawDeg)) * .pi / 180.0)
            let clampedRoll = Float(max(-35.0, min(35.0, rollDeg)) * .pi / 180.0)

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.08
            root.eulerAngles = SCNVector3(clampedPitch, clampedYaw, -clampedRoll)
            SCNTransaction.commit()
        }
    }

    final class Coordinator {
        var headsetRoot: SCNNode?
        var modelContainer: SCNNode?
        var ringMaterial: SCNMaterial?
        var lastModel: HeadphoneModelKind?
        var lastMaxColor: AirPodsMaxColor?
    }

    // MARK: - 6 款耳机 3D 程序化 PBR 构建器

    private func rebuildGeometry(in container: SCNNode, model: HeadphoneModelKind, maxColor: AirPodsMaxColor) {
        container.childNodes.forEach { $0.removeFromParentNode() }

        switch model {
        case .airPodsPro2:
            buildInEarPair(container: container, variant: .pro2)
        case .airPods4:
            buildInEarPair(container: container, variant: .gen4)
        case .airPods2:
            buildInEarPair(container: container, variant: .gen2)
        case .airPodsMax:
            buildAirPodsMax(container: container, maxColor: maxColor)
        case .beatsFitPro:
            buildBeatsFitPro(container: container)
        case .beatsStudioPro:
            buildBeatsStudioPro(container: container)
        }
    }

    private enum InEarVariant { case pro2, gen4, gen2 }

    private func buildInEarPair(container: SCNNode, variant: InEarVariant) {
        let glossWhite = pbrMaterial(color: UIColor(white: 0.96, alpha: 1.0), metalness: 0.05, roughness: 0.14)
        let siliconeMat = pbrMaterial(color: UIColor(white: 0.92, alpha: 0.88), metalness: 0.0, roughness: 0.55)
        let darkMeshMat = pbrMaterial(color: UIColor(white: 0.09, alpha: 1.0), metalness: 0.35, roughness: 0.45)

        for side in [-1.0, 1.0] {
            let s = Float(side)
            let pod = SCNNode()
            pod.position = SCNVector3(s * 0.50, 0.06, 0)
            pod.eulerAngles = SCNVector3(0.08, -s * 0.25, -s * 0.06)

            // 主声学腔体
            let headGeo = SCNSphere(radius: variant == .pro2 ? 0.25 : 0.22)
            headGeo.materials = [glossWhite]
            let head = SCNNode(geometry: headGeo)
            head.scale = SCNVector3(0.95, 1.02, 1.15)
            pod.addChildNode(head)

            // 耳机柄部（2 代最长，4/Pro 2 短柄带电容触控槽）
            let stemLength: CGFloat = variant == .gen2 ? 0.68 : (variant == .gen4 ? 0.46 : 0.44)
            let stemGeo = SCNCapsule(capRadius: 0.058, height: stemLength)
            stemGeo.materials = [glossWhite]
            let stem = SCNNode(geometry: stemGeo)
            stem.position = SCNVector3(0, -Float(stemLength * 0.5) - 0.06, 0.06)
            stem.eulerAngles = SCNVector3(0.18, 0, s * 0.08)
            pod.addChildNode(stem)

            // 黑色防风麦克风网罩
            let ventGeo = SCNBox(width: 0.075, height: 0.11, length: 0.025, chamferRadius: 0.01)
            ventGeo.materials = [darkMeshMat]
            let vent = SCNNode(geometry: ventGeo)
            vent.position = SCNVector3(s * 0.15, 0.05, 0.19)
            pod.addChildNode(vent)

            // Pro 2 的触控电容长条凹槽 + 硅胶入耳塞
            if variant == .pro2 {
                let slotGeo = SCNBox(width: 0.032, height: 0.15, length: 0.018, chamferRadius: 0.008)
                slotGeo.materials = [darkMeshMat]
                let slot = SCNNode(geometry: slotGeo)
                slot.position = SCNVector3(s * 0.04, -0.24, 0.10)
                pod.addChildNode(slot)

                let nozzleGeo = SCNCylinder(radius: 0.095, height: 0.15)
                nozzleGeo.materials = [siliconeMat]
                let nozzle = SCNNode(geometry: nozzleGeo)
                nozzle.position = SCNVector3(-s * 0.22, -0.02, -0.04)
                nozzle.eulerAngles = SCNVector3(0, 0, s * Float.pi / 2.2)
                pod.addChildNode(nozzle)

                let tipGeo = SCNSphere(radius: 0.155)
                tipGeo.materials = [siliconeMat]
                let tip = SCNNode(geometry: tipGeo)
                tip.position = SCNVector3(-s * 0.28, -0.03, -0.05)
                tip.scale = SCNVector3(0.70, 1.0, 1.05)
                pod.addChildNode(tip)
            } else {
                // 4/3/2 半入耳内侧声学出音嘴
                let tipGeo = SCNCylinder(radius: 0.085, height: 0.14)
                tipGeo.materials = [darkMeshMat]
                let tip = SCNNode(geometry: tipGeo)
                tip.position = SCNVector3(-s * 0.18, -0.02, -0.05)
                tip.eulerAngles = SCNVector3(0, 0, s * Float.pi / 2.2)
                pod.addChildNode(tip)
            }

            container.addChildNode(pod)
        }
    }

    private func buildAirPodsMax(container: SCNNode, maxColor: AirPodsMaxColor) {
        let rgb = maxColor.rgb
        let shellColor = UIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1.0)
        let cushionColor = UIColor(
            red: min(1.0, rgb.r * 0.82 + 0.10),
            green: min(1.0, rgb.g * 0.82 + 0.10),
            blue: min(1.0, rgb.b * 0.82 + 0.10),
            alpha: 1.0
        )
        let aluMat = pbrMaterial(color: shellColor, metalness: 0.82, roughness: 0.24)
        let steelMat = pbrMaterial(color: UIColor(white: 0.88, alpha: 1.0), metalness: 0.92, roughness: 0.16)
        let fabricMat = pbrMaterial(color: cushionColor, metalness: 0.04, roughness: 0.78)
        let canopyMat = pbrMaterial(color: cushionColor.withAlphaComponent(0.92), metalness: 0.08, roughness: 0.65)

        // 顶部不锈钢拱形骨架 + 透气网布穹顶
        let segCount = 22
        let archRadiusX: Float = 0.72
        let archRadiusY: Float = 0.68
        for i in 0...segCount {
            let frac = Float(i) / Float(segCount)
            let theta = Float.pi * (0.08 + 0.84 * frac) // 从右侧到左侧顶部圆弧
            let x = cos(theta) * archRadiusX
            let y = sin(theta) * archRadiusY + 0.10

            for zOffset in [-0.075, 0.075] as [Float] {
                let railGeo = SCNSphere(radius: 0.028)
                railGeo.materials = [steelMat]
                let rail = SCNNode(geometry: railGeo)
                rail.position = SCNVector3(x, y, zOffset)
                container.addChildNode(rail)
            }

            // 中间透气编织穹顶带
            let meshGeo = SCNBox(width: 0.085, height: 0.02, length: 0.14, chamferRadius: 0.008)
            meshGeo.materials = [canopyMat]
            let mesh = SCNNode(geometry: meshGeo)
            mesh.position = SCNVector3(x, y, 0)
            mesh.eulerAngles = SCNVector3(0, 0, theta - Float.pi / 2)
            container.addChildNode(mesh)
        }

        // 左右伸缩杆 + 阳极氧化铝椭圆耳罩 + 记忆棉耳垫
        for side in [-1.0, 1.0] {
            let s = Float(side)
            let armGeo = SCNCylinder(radius: 0.028, height: 0.34)
            armGeo.materials = [steelMat]
            let arm = SCNNode(geometry: armGeo)
            arm.position = SCNVector3(s * 0.70, 0.05, 0)
            arm.eulerAngles = SCNVector3(0, 0, s * 0.08)
            container.addChildNode(arm)

            let cupGroup = SCNNode()
            cupGroup.position = SCNVector3(s * 0.66, -0.26, 0)
            cupGroup.eulerAngles = SCNVector3(0, 0, -s * 0.08)

            // 阳极氧化铝外壳
            let cupGeo = SCNCylinder(radius: 0.31, height: 0.18)
            cupGeo.materials = [aluMat]
            let cup = SCNNode(geometry: cupGeo)
            cup.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            cup.scale = SCNVector3(1.0, 1.0, 1.24)
            cupGroup.addChildNode(cup)

            // 织物记忆棉耳垫
            let padGeo = SCNTorus(ringRadius: 0.24, pipeRadius: 0.085)
            padGeo.materials = [fabricMat]
            let pad = SCNNode(geometry: padGeo)
            pad.position = SCNVector3(-s * 0.11, 0, 0)
            pad.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            pad.scale = SCNVector3(1.22, 1.0, 0.96)
            cupGroup.addChildNode(pad)

            // 右侧耳罩顶部 Digital Crown 数码旋钮
            if side > 0 {
                let crownGeo = SCNCylinder(radius: 0.045, height: 0.055)
                crownGeo.materials = [steelMat]
                let crown = SCNNode(geometry: crownGeo)
                crown.position = SCNVector3(0.02, 0.38, -0.05)
                cupGroup.addChildNode(crown)
            }

            container.addChildNode(cupGroup)
        }
    }

    private func buildBeatsFitPro(container: SCNNode) {
        let matteBody = pbrMaterial(color: UIColor(white: 0.14, alpha: 1.0), metalness: 0.22, roughness: 0.45)
        let accentMat = pbrMaterial(color: UIColor(red: 0.92, green: 0.22, blue: 0.24, alpha: 1.0), metalness: 0.15, roughness: 0.35)
        let tipMat = pbrMaterial(color: UIColor(white: 0.22, alpha: 1.0), metalness: 0.0, roughness: 0.6)

        for side in [-1.0, 1.0] {
            let s = Float(side)
            let bud = SCNNode()
            bud.position = SCNVector3(s * 0.48, 0.02, 0)
            bud.eulerAngles = SCNVector3(0.1, -s * 0.28, 0)

            let bodyGeo = SCNSphere(radius: 0.25)
            bodyGeo.materials = [matteBody]
            let body = SCNNode(geometry: bodyGeo)
            body.scale = SCNVector3(0.88, 1.05, 1.15)
            bud.addChildNode(body)

            // Beats b 标志小圆盘
            let badgeGeo = SCNCylinder(radius: 0.11, height: 0.04)
            badgeGeo.materials = [accentMat]
            let badge = SCNNode(geometry: badgeGeo)
            badge.position = SCNVector3(s * 0.18, 0, 0.05)
            badge.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            bud.addChildNode(badge)

            // 弯曲运动耳翼（Wingtip）
            let wingGeo = SCNCapsule(capRadius: 0.06, height: 0.42)
            wingGeo.materials = [matteBody]
            let wing = SCNNode(geometry: wingGeo)
            wing.position = SCNVector3(s * 0.04, 0.26, -0.06)
            wing.eulerAngles = SCNVector3(-0.35, 0, s * 0.55)
            bud.addChildNode(wing)

            // 硅胶耳塞
            let tipGeo = SCNSphere(radius: 0.14)
            tipGeo.materials = [tipMat]
            let tip = SCNNode(geometry: tipGeo)
            tip.position = SCNVector3(-s * 0.24, -0.04, 0)
            tip.scale = SCNVector3(0.75, 1.0, 1.0)
            bud.addChildNode(tip)

            container.addChildNode(bud)
        }
    }

    private func buildBeatsStudioPro(container: SCNNode) {
        let darkTitanium = pbrMaterial(color: UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0), metalness: 0.42, roughness: 0.38)
        let cushionMat = pbrMaterial(color: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0), metalness: 0.05, roughness: 0.68)
        let silverAccent = pbrMaterial(color: UIColor(white: 0.78, alpha: 1.0), metalness: 0.85, roughness: 0.22)
        let redLogo = pbrMaterial(color: UIColor(red: 0.94, green: 0.24, blue: 0.24, alpha: 1.0), metalness: 0.2, roughness: 0.3)

        let segCount = 24
        for i in 0...segCount {
            let frac = Float(i) / Float(segCount)
            let theta = Float.pi * (0.06 + 0.88 * frac)
            let x = cos(theta) * 0.72
            let y = sin(theta) * 0.72 + 0.06

            let bandGeo = SCNBox(width: 0.11, height: 0.065, length: 0.22, chamferRadius: 0.025)
            bandGeo.materials = [darkTitanium]
            let band = SCNNode(geometry: bandGeo)
            band.position = SCNVector3(x, y, 0)
            band.eulerAngles = SCNVector3(0, 0, theta - Float.pi / 2)
            container.addChildNode(band)
        }

        for side in [-1.0, 1.0] {
            let s = Float(side)
            let cupGroup = SCNNode()
            cupGroup.position = SCNVector3(s * 0.66, -0.22, 0)
            cupGroup.eulerAngles = SCNVector3(0, 0, -s * 0.09)

            // 银色金属折叠铰链环
            let hingeGeo = SCNCylinder(radius: 0.07, height: 0.14)
            hingeGeo.materials = [silverAccent]
            let hinge = SCNNode(geometry: hingeGeo)
            hinge.position = SCNVector3(s * 0.06, 0.28, 0)
            cupGroup.addChildNode(hinge)

            let cupGeo = SCNCylinder(radius: 0.29, height: 0.16)
            cupGeo.materials = [darkTitanium]
            let cup = SCNNode(geometry: cupGeo)
            cup.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            cup.scale = SCNVector3(1.0, 1.0, 1.25)
            cupGroup.addChildNode(cup)

            // 外侧招牌徽标盘
            let logoGeo = SCNCylinder(radius: 0.12, height: 0.02)
            logoGeo.materials = [redLogo]
            let logo = SCNNode(geometry: logoGeo)
            logo.position = SCNVector3(s * 0.085, 0, 0)
            logo.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            cupGroup.addChildNode(logo)

            let padGeo = SCNTorus(ringRadius: 0.22, pipeRadius: 0.08)
            padGeo.materials = [cushionMat]
            let pad = SCNNode(geometry: padGeo)
            pad.position = SCNVector3(-s * 0.10, 0, 0)
            pad.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            pad.scale = SCNVector3(1.22, 1.0, 0.96)
            cupGroup.addChildNode(pad)

            container.addChildNode(cupGroup)
        }
    }

    private func pbrMaterial(color: UIColor, metalness: CGFloat, roughness: CGFloat) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = color
        mat.metalness.contents = metalness
        mat.roughness.contents = roughness
        return mat
    }
}
