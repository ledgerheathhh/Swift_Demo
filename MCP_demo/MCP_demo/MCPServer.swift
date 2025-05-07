//
//  MCPServer.swift
//  MCP_demo
//
//  Created by Ledger Heath on 2025/5/7.
//

import Foundation
import Network

// MCP服务器代理协议
protocol MCPServerDelegate: AnyObject {
    func mcpServer(_ server: MCPServer, didReceiveEvent event: [String: Any])
    func mcpServer(_ server: MCPServer, didEncounterError error: Error)
}

class MCPServer {
    // 服务器端口
    private let port: UInt16
    // 网络监听器
    private var listener: NWListener?
    // 连接列表
    private var connections: [NWConnection] = []
    // 代理
    weak var delegate: MCPServerDelegate?
    
    init(port: Int) {
        self.port = UInt16(port)
    }
    
    // 启动服务器
    func start() {
        do {
            // 创建TCP监听器
            let parameters = NWParameters.tcp
            // Fix: Safely unwrap the optional Port value
            guard let port = NWEndpoint.Port(rawValue: port) else {
                let error = NSError(domain: "MCPServerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid port number"])
                print("启动MCP服务器失败: \(error)")
                delegate?.mcpServer(self, didEncounterError: error)
                return
            }
            listener = try NWListener(using: parameters, on: port)
            
            // 设置状态变化处理
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    print("MCP服务器已准备就绪")
                case .failed(let error):
                    print("MCP服务器启动失败: \(error)")
                    self?.delegate?.mcpServer(self!, didEncounterError: error)
                default:
                    break
                }
            }
            
            // 设置新连接处理
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            // 启动监听
            listener?.start(queue: .main)
        } catch {
            print("启动MCP服务器失败: \(error)")
            delegate?.mcpServer(self, didEncounterError: error)
        }
    }
    
    // 停止服务器
    func stop() {
        listener?.cancel()
        
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
    }
    
    // 处理新连接
    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)
        
        // 设置连接状态处理
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("客户端已连接")
                self?.receiveData(from: connection)
            case .failed(let error):
                print("连接失败: \(error)")
                self?.removeConnection(connection)
            case .cancelled:
                print("连接已取消")
                self?.removeConnection(connection)
            default:
                break
            }
        }
        
        // 启动连接
        connection.start(queue: .main)
    }
    
    // 从连接中接收数据
    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                // 处理接收到的数据
                self?.handleReceivedData(data, from: connection)
            }
            
            if let error = error {
                print("接收数据错误: \(error)")
                self?.delegate?.mcpServer(self!, didEncounterError: error)
                self?.removeConnection(connection)
                return
            }
            
            if isComplete {
                self?.removeConnection(connection)
                return
            }
            
            // 继续接收数据
            self?.receiveData(from: connection)
        }
    }
    
    // 处理接收到的数据
    private func handleReceivedData(_ data: Data, from connection: NWConnection) {
        // 尝试解析JSON数据
        if let jsonString = String(data: data, encoding: .utf8),
           let jsonData = jsonString.data(using: .utf8),
           let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            // 通知代理收到事件
            delegate?.mcpServer(self, didReceiveEvent: event)
            
            // 发送响应
            let response = ["status": "success", "message": "Event received"]
            sendResponse(response, to: connection)
        } else {
            // 发送错误响应
            let response = ["status": "error", "message": "Invalid JSON data"]
            sendResponse(response, to: connection)
        }
    }
    
    // 发送响应
    private func sendResponse(_ response: [String: String], to connection: NWConnection) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: response)
            connection.send(content: jsonData, completion: .contentProcessed { error in
                if let error = error {
                    print("发送响应错误: \(error)")
                }
            })
        } catch {
            print("序列化响应错误: \(error)")
        }
    }
    
    // 移除连接
    private func removeConnection(_ connection: NWConnection) {
        if let index = connections.firstIndex(where: { $0 === connection }) {
            connections.remove(at: index)
        }
    }
    
    // 处理事件（供应用内部使用）
    func processEvent(_ event: [String: Any]) {
        // 模拟处理事件
        print("处理内部事件: \(event)")
        delegate?.mcpServer(self, didReceiveEvent: event)
    }
}