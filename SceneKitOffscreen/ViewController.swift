//
//  ViewController.swift
//  SceneKitOffscreen
//
//  Created by Lachlan Hurst on 24/10/2015.
//  Copyright © 2015 Lachlan Hurst. All rights reserved.
//

import UIKit
import SceneKit
import Metal

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
    var textureSizeX:Int = 50
    var textureSizeY:Int = 50
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scene1 = SCNScene()
        
        let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        box.materials.first?.diffuse.contents = UIColor.red
        let boxNode = SCNNode(geometry: box)
        scene1.rootNode.addChildNode(boxNode)
        
        let sphere = SCNSphere(radius: 1)
        sphere.materials.first?.diffuse.contents = UIColor.yellow
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.position = SCNVector3Make(2, 0, 0)
        scene1.rootNode.addChildNode(sphereNode)
        
        scnView1.scene = scene1
        
        
        scene2 = SCNScene()
        
        plane = SCNPlane(width: 10, height: 10)
        let planeNode = SCNNode(geometry: plane)
        scene2.rootNode.addChildNode(planeNode)
        
        scnView2.scene = scene2
        
        
        
        scnView1.autoenablesDefaultLighting = true
        scnView2.autoenablesDefaultLighting = true
        scnView1.allowsCameraControl = true
        scnView2.allowsCameraControl = true
        //scnView1.showsStatistics = true
        //scnView2.showsStatistics = true
        scnView1.isPlaying = true
        scnView2.isPlaying = true
        
        scnView1.delegate = self
        
        setupMetal()
        setupTexture()
        
        plane.materials.first?.diffuse.contents = offscreenTexture
    }

    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        doRender()
    }
    
    func doRender() {
        //rendering to a MTLTexture, so the viewport is the size of this texture
        let viewport = CGRect(x: 0, y: 0, width: CGFloat(textureSizeX), height: CGFloat(textureSizeY))
        
        //write to offscreenTexture, clear the texture before rendering using green, store the result
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = offscreenTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 1, 0, 1.0); //green
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        let commandBuffer = commandQueue.makeCommandBuffer()
        
        // reuse scene1 and the current point of view
        renderer.scene = scene1
        renderer.pointOfView = scnView1.pointOfView
        renderer.render(atTime: 0, viewport: viewport, commandBuffer: commandBuffer, passDescriptor: renderPassDescriptor)

        commandBuffer.commit()
    }
    
    func setupMetal() {
        if self.scnView1.renderingAPI == SCNRenderingAPI.metal {
            device = scnView1.device
            commandQueue = device.makeCommandQueue()
            renderer = SCNRenderer(device: device, options: nil)
        } else {
            fatalError("Sorry, Metal only")
        }
    }
    
    func setupTexture() {
        
        var rawData0 = [UInt8](repeating: 0, count: Int(textureSizeX) * Int(textureSizeY) * 4)
        
        let bytesPerRow = 4 * Int(textureSizeX)
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        
        let context = CGContext(data: &rawData0, width: Int(textureSizeX), height: Int(textureSizeY), bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: rgbColorSpace, bitmapInfo: bitmapInfo)!
        context.setFillColor(UIColor.green.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(textureSizeX), height: CGFloat(textureSizeY)))

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.rgba8Unorm, width: Int(textureSizeX), height: Int(textureSizeY), mipmapped: false)
        
        let textureA = device.makeTexture(descriptor: textureDescriptor)
        
        let region = MTLRegionMake2D(0, 0, Int(textureSizeX), Int(textureSizeY))
        textureA.replace(region: region, mipmapLevel: 0, withBytes: &rawData0, bytesPerRow: Int(bytesPerRow))

        offscreenTexture = textureA
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

