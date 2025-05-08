//
//  ViewController.swift
//  MCP_demo
//
//  Created by Ledger Heath on 2025/5/7.
//

import UIKit
import MCP

class ViewController: UIViewController {
    var client: Client?
    var clientTransport: Transport? // 客户端传输层
    var server: Server?
    var serverTransport: Transport? // 服务器传输层
    
    // 存储任务引用以便后续取消
    private var serverTask: Task<Void, Never>?
    private var clientTask: Task<Void, Never>?
    
    // 状态管理
    private var isServerRunning = false
    private var isClientConnected = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // 初始化 MCP 服务器
        setupMCPServer()
        
        // 等待服务器启动后再初始化客户端
        Task {
            // 等待一小段时间确保服务器启动
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 等待1秒
            
            await MainActor.run {
                // 初始化 MCP 客户端
                setupMCPClient()
                
                // 添加调用工具的按钮
                setupCallToolButton()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 视图消失时取消任务
        serverTask?.cancel()
        clientTask?.cancel()
    }

    func setupMCPClient() {
        client = Client(name: "MCPDemoApp", version: "1.0.0")
//        clientTransport = HTTPClientTransport(endpoint: URL(string: "http://localhost:8080")!, streaming: true)
        clientTransport = StdioTransport()

        clientTask = Task {
            do {
                // 连接到 MCP 服务器
                guard let transport = clientTransport else {
                    print("客户端传输层未正确初始化")
                    throw MCPError.invalidParams("客户端传输层未正确初始化")
                }
                try await client?.connect(transport: transport)
                let result = try await client?.initialize()
                
                // 在主线程更新UI状态
                await MainActor.run {
                    isClientConnected = true
                    print("客户端连接成功，服务器功能: \(String(describing: result?.capabilities))")
                }
            } catch {
                if Task.isCancelled {
                    print("客户端连接任务已取消")
                } else {
                    // 在主线程更新UI状态
                    await MainActor.run {
                        print("MCP 客户端初始化失败: \(error)")
                    }
                }
            }
        }
    }

    @objc func callTool() {
        // 检查客户端是否已连接
        guard isClientConnected else {
            print("客户端未连接，无法调用工具")
            return
        }
        
        Task {
            do {
                // 调用 MCP 工具
                let (content, _) = try await client?.callTool(
                    name: "example-tool",
                    arguments: ["key": "value"]
                ) ?? ([], false)

                await MainActor.run {
                    // 解析工具调用返回内容
                    for item in content {
                        switch item {
                        case .text(let text):
                            print("工具返回文本: \(text)")
                        default:
                            print("未处理的返回类型")
                        }
                    }
                }
            } catch {
                if Task.isCancelled {
                    print("工具调用任务已取消")
                } else {
                    await MainActor.run {
                        print("工具调用失败: \(error)")
                    }
                }
            }
        }
    }

    func setupMCPServer() {
        server = Server(
            name: "MyModelServer",
            version: "1.0.0",
            capabilities: .init(
                prompts: .init(listChanged: true),
                resources: .init(subscribe: true, listChanged: true),
                tools: .init(listChanged: true)
            )
        )
        
        serverTransport = StdioTransport()
    
        serverTask = Task {
            do {
                // 启动 MCP 服务器
                guard let transport = serverTransport else {
                    throw MCPError.invalidParams("服务器传输层未正确初始化")
                }
                try await server?.start(transport: transport)
                
                // 在主线程更新UI状态
                await MainActor.run {
                    isServerRunning = true
                    print("MCP 服务器已启动")
                }
                
                // 注册工具
                Task {
                    registerTools()
                }
            } catch {
                if Task.isCancelled {
                    print("服务器启动任务已取消")
                } else {
                    // 在主线程更新UI状态
                    await MainActor.run {
                        print("MCP 服务器启动失败: \(error)")
                    }
                }
            }
        }
    }

    func registerTools() {
        // 使用Task从同步上下文调用actor隔离方法
        Task {
            await server?.withMethodHandler(CallTool.self) { params in
                switch params.name {
                case "example-tool":
                    return .init(content: [.text("工具调用成功")], isError: false)
                default:
                    return .init(content: [.text("未知工具")], isError: true)
                }
            }
        }
    }

    func setupCallToolButton() {
        let button = UIButton(type: .system)
        button.setTitle("调用工具", for: .normal)
        button.addTarget(self, action: #selector(callTool), for: .touchUpInside)

        // 使用自动布局
        button.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 200),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
}
