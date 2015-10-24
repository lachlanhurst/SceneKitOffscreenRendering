//
//  ViewController.swift
//  SceneKitOffscreen
//
//  Created by Lachlan Hurst on 24/10/2015.
//  Copyright © 2015 Lachlan Hurst. All rights reserved.
//

import UIKit
import SceneKit

class ViewController: UIViewController, SCNSceneRendererDelegate {
    @IBOutlet var scnView1: SCNView!
    @IBOutlet var scnView2: SCNView!

    var scene1:SCNScene!
    var scene2:SCNScene!
    
    var plane:SCNGeometry!
    
    var device:MTLDevice!
    var commandQueue: MTLCommandQueue!
    var renderer: SCNRenderer!
    
    var offscreenTexture:MTLTexture!
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerPixel = Int(4)
    let bitsPerComponent = Int(8)
    let bitsPerPixel:Int = 32
    
    var sizeX:Int = 400
    var sizeY:Int = 1200
    
    var textureSizeX:Int!
    var textureSizeY:Int!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scene1 = SCNScene()
        
        let box = SCNBox(width: 40, height: 400, length: 40, chamferRadius: 0)
        box.materials.first?.diffuse.contents = UIColor.redColor()
        let boxNode = SCNNode(geometry: box)
        var boxTransform = SCNMatrix4Identity
        boxTransform = SCNMatrix4Rotate(boxTransform, 20 * Float(M_PI) / 180, 0, 1, 0)
        boxTransform = SCNMatrix4Rotate(boxTransform, 60 * Float(M_PI) / 180, 1, 0, 0)
        boxTransform = SCNMatrix4Translate(boxTransform, Float(sizeX/2), 0, Float(sizeY/2))
        boxNode.transform = boxTransform

        let floor = SCNFloor()
        floor.reflectivity = 0
        floor.materials.first?.diffuse.contents = UIColor.blackColor()
        let floorNode = SCNNode(geometry: floor)
        scene1.rootNode.addChildNode(floorNode)
        
        
        scene1.rootNode.addChildNode(boxNode)
        
        let sphere = SCNSphere(radius: 30)
        sphere.materials.first?.diffuse.contents = UIColor.redColor()
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.position = SCNVector3Make(0, 0, 0)
        scene1.rootNode.addChildNode(sphereNode)
        
        let sphereMaxX = SCNSphere(radius: 30)
        sphereMaxX.materials.first?.diffuse.contents = UIColor.greenColor()
        let sphereMaxXNode = SCNNode(geometry: sphereMaxX)
        sphereMaxXNode.position = SCNVector3Make(Float(sizeX), 0, 0)
        scene1.rootNode.addChildNode(sphereMaxXNode)
        
        let sphereMaxXY = SCNSphere(radius: 30)
        sphereMaxXY.materials.first?.diffuse.contents = UIColor.blueColor()
        let sphereMaxXYNode = SCNNode(geometry: sphereMaxXY)
        sphereMaxXYNode.position = SCNVector3Make(Float(sizeX), 0, Float(sizeY))
        scene1.rootNode.addChildNode(sphereMaxXYNode)
        
        let orthoScale = min(Double(sizeX),Double(sizeY))/2
        
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = orthoScale
        camera.zFar = 1000
        camera.zNear = 10
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        var cameraTransform = SCNMatrix4Identity
        cameraTransform = SCNMatrix4Rotate(cameraTransform, -90 * Float(M_PI) / 180, 1, 0, 0)
        cameraTransform = SCNMatrix4Translate(cameraTransform, Float(sizeX)/2, 300, Float(sizeY)/2)
        cameraNode.transform = cameraTransform
        
        scene1.rootNode.addChildNode(cameraNode)
        
        
        scnView1.scene = scene1
        
        
        scene2 = SCNScene()
        
        plane = SCNPlane(width: CGFloat(sizeX), height: CGFloat(sizeY))
        let planeNode = SCNNode(geometry: plane)
        scene2.rootNode.addChildNode(planeNode)
        
        scnView2.scene = scene2
        
        scnView1.autoenablesDefaultLighting = true
        scnView2.autoenablesDefaultLighting = true
        scnView1.allowsCameraControl = true
        scnView2.allowsCameraControl = true
        //scnView1.showsStatistics = true
        //scnView2.showsStatistics = true
        scnView1.playing = true
        scnView2.playing = true
        
        scnView1.delegate = self
        
        setupMetal()
        setupTexture()
        
        plane.materials.first?.diffuse.contents = offscreenTexture
    }

    func renderer(renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: NSTimeInterval) {
        doRender()
    }
    
    func doRender() {
        //rendering to a MTLTexture, so the viewport is the size of this texture
        let viewport = CGRectMake(0, 0, CGFloat(textureSizeX), CGFloat(textureSizeY))
        
        //write to offscreenTexture, clear the texture before rendering using green, store the result
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = offscreenTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .Clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.2, 0.2, 1.0);
        renderPassDescriptor.colorAttachments[0].storeAction = .Store

        let commandBuffer = commandQueue.commandBuffer()
        
        // reuse scene1 and the current point of view
        renderer.scene = scene1
        renderer.pointOfView = scnView1.pointOfView
        renderer.renderAtTime(0, viewport: viewport, commandBuffer: commandBuffer, passDescriptor: renderPassDescriptor)
        
        commandBuffer.commit()
    }
    
    func setupMetal() {
        if self.scnView1.renderingAPI == SCNRenderingAPI.Metal {
            device = scnView1.device
            commandQueue = device.newCommandQueue()
            renderer = SCNRenderer(device: device, options: nil)
        } else {
            fatalError("Sorry, Metal only")
        }
    }
    
    func setupTexture() {
        
        self.textureSizeX = 2 * sizeX
        self.textureSizeY = 2 * sizeY
        
        var rawData0 = [UInt8](count: Int(textureSizeX) * Int(textureSizeY) * 4, repeatedValue: 0)
        
        let bytesPerRow = 4 * Int(textureSizeX)
        let bitmapInfo = CGBitmapInfo.ByteOrder32Big.rawValue | CGImageAlphaInfo.PremultipliedLast.rawValue
        
        let context = CGBitmapContextCreate(&rawData0, Int(textureSizeX), Int(textureSizeY), bitsPerComponent, bytesPerRow, rgbColorSpace, bitmapInfo)
        CGContextSetFillColorWithColor(context, UIColor.greenColor().CGColor)
        CGContextFillRect(context, CGRectMake(0, 0, CGFloat(textureSizeX), CGFloat(textureSizeY)))

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.RGBA8Unorm, width: Int(textureSizeX), height: Int(textureSizeY), mipmapped: false)
        
        let textureA = device.newTextureWithDescriptor(textureDescriptor)
        
        let region = MTLRegionMake2D(0, 0, Int(textureSizeX), Int(textureSizeY))
        textureA.replaceRegion(region, mipmapLevel: 0, withBytes: &rawData0, bytesPerRow: Int(bytesPerRow))

        offscreenTexture = textureA
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

