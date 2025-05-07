//
//  ViewController.swift
//  MCP_demo
//
//  Created by Ledger Heath on 2025/5/7.
//

import UIKit
import WebKit

class ViewController: UIViewController {
    
    // MCP服务器的端口
    private let mcpPort = 8080
    // MCP服务器实例
    private var mcpServer: MCPServer?
    // 用于显示操作结果的标签
    private let resultLabel = UILabel()
    // 测试按钮
    private let testButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startMCPServer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopMCPServer()
    }
    
    // 设置UI界面
    private func setupUI() {
        view.backgroundColor = .white
        
        // 配置结果标签
        resultLabel.frame = CGRect(x: 20, y: 100, width: view.bounds.width - 40, height: 40)
        resultLabel.textAlignment = .center
        resultLabel.text = "等待操作..."
        view.addSubview(resultLabel)
        
        // 配置测试按钮
        testButton.frame = CGRect(x: (view.bounds.width - 200) / 2, y: 200, width: 200, height: 50)
        testButton.setTitle("发送点击事件", for: .normal)
        testButton.addTarget(self, action: #selector(testButtonTapped), for: .touchUpInside)
        view.addSubview(testButton)
    }
    
    // 启动MCP服务器
    private func startMCPServer() {
        mcpServer = MCPServer(port: mcpPort)
        mcpServer?.delegate = self
        mcpServer?.start()
        print("MCP服务器已启动，端口：\(mcpPort)")
    }
    
    // 停止MCP服务器
    private func stopMCPServer() {
        mcpServer?.stop()
        mcpServer = nil
        print("MCP服务器已停止")
    }
    
    // 按钮点击事件
    @objc private func testButtonTapped() {
        // 模拟向MCP服务器发送点击事件
        let clickEvent = ["type": "click", "x": 100, "y": 100] as [String : Any]
        mcpServer?.processEvent(clickEvent)
    }
}

// MARK: - MCPServerDelegate
extension ViewController: MCPServerDelegate {
    func mcpServer(_ server: MCPServer, didReceiveEvent event: [String: Any]) {
        // 处理从MCP服务器接收到的事件
        DispatchQueue.main.async { [weak self] in
            if let type = event["type"] as? String {
                self?.resultLabel.text = "收到事件: \(type)"
                print("处理事件: \(event)")
            }
        }
    }
    
    func mcpServer(_ server: MCPServer, didEncounterError error: Error) {
        // 处理MCP服务器错误
        DispatchQueue.main.async { [weak self] in
            self?.resultLabel.text = "服务器错误: \(error.localizedDescription)"
            print("MCP服务器错误: \(error)")
        }
    }
}

