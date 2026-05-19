// swift-actor-demo.swift

import Foundation

// ============ 基本 Actor ============
actor BankAccount {
    private var balance: Double = 0

    func deposit(_ amount: Double) {
        balance += amount
        print("存款: \(amount), 余额: \(balance)")
    }

    func withdraw(_ amount: Double) -> Bool {
        if balance >= amount {
            balance -= amount
            print("取款: \(amount), 余额: \(balance)")
            return true
        }
        print("余额不足")
        return false
    }

    func getBalance() -> Double {
        return balance
    }
}

Task {
    let account = BankAccount()
    await account.deposit(1000)
    await account.withdraw(500)
    let balance = await account.getBalance()
    print("最终余额: \(balance)")
}

// ============ Actor 隔离 ============
actor DataManager {
    private var data: [String] = []

    func add(_ item: String) {
        data.append(item)
    }

    func getAll() -> [String] {
        return data
    }

    // 访问其他 actor
    func process(using processor: Processor) async {
        let items = await processor.process(self.data)
        self.data = items
    }
}

actor Processor {
    func process(_ items: [String]) async -> [String] {
        return items.map { $0.uppercased() }
    }
}

// ============ Sendable ============
// Sendable 类型可以在线程/actor间安全传递
struct User: Sendable {
    let name: String
    let age: Int
}

func fetchUser() async -> User {
    return User(name: "Tom", age: 25)
}

Task {
    let user = await fetchUser()
    print("用户: \(user.name), 年龄: \(user.age)")
}

// ============ Actor 重入 ============
actor Counter {
    private var count = 0

    func increment() {
        count += 1
    }

    func getCount() -> Int {
        return count
    }
}

Task {
    let counter = Counter()

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<10 {
            group.addTask {
                await counter.increment()
            }
        }
    }

    let finalCount = await counter.getCount()
    print("最终计数: \(finalCount)")
}

// ============ Nonisolated ============
actor Logger {
    private var logs: [String] = []

    func log(_ message: String) {
        logs.append(message)
    }

    nonisolated var timestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}

Task {
    let logger = Logger()
    await logger.log("开始")
    await logger.log("结束")
    print("时间戳: \(logger.timestamp)")
}
