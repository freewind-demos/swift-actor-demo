# Swift Actor 并发 Demo

## 简介

本 demo 展示 Swift 中 Actor 的用法。Actor 是 Swift 5.5 引入的**线程安全的数据类型**，用于解决并发编程中的数据竞争问题。

## 基本原理

### 什么是 Actor？

Actor 是 Swift 并发模型中的核心概念之一。在传统的多线程编程中，多个线程同时访问共享数据会导致**数据竞争（Data Race）**，造成不可预期的错误。

Actor 通过以下机制解决这个问题：

1. **互斥访问**：Actor 内部的属性只能被 Actor 自身的方法访问
2. **自动同步**：访问 Actor 的属性会自动进行线程同步
3. **隔离机制**：Actor 之间通过消息传递进行通信

### Actor 的工作原理

```
传统方式：                          Actor 方式：
┌─────────────┐                    ┌─────────────┐
│  Thread 1   │                    │   Actor     │
│  ────────   │  ────────►       │  ─────────  │
│  写数据     │  数据竞争!        │  互斥访问   │
└─────────────┘                    │  自动同步   │
┌─────────────┐                    └─────────────┘
│  Thread 2   │                          ▲
│  ────────   │  ────────►              │
│  读数据     │                          │
└─────────────┘                    ┌───────────┐
                                   │ Thread 1  │
                                   │ Thread 2  │
                                   └───────────┘
```

### Sendable 协议

Sendable 是 Swift 并发中的重要协议，用于标记**可以安全在线程间传递的类型**。Actor 内部的属性必须是 Sendable 类型。

---

## 启动和使用

### 环境要求

- Swift 5.5+（Actor 是 Swift 5.5 引入的）
- macOS 或 Linux

### 安装和运行

```bash
cd swift-actor-demo
swift run
```

---

## 教程

### Actor 的基本用法

Actor 和类（class）类似，但是提供了**内置的线程安全**。

```swift
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
```

使用 Actor：

```swift
Task {
    let account = BankAccount()
    await account.deposit(1000)
    await account.withdraw(500)
    let balance = await account.getBalance()
    print("最终余额: \(balance)")
}
```

**注意**：访问 Actor 的属性和方法需要使用 `await`，因为 Actor 会自动处理线程同步。

### Actor 的互斥特性

Actor 最重要的特性是**一次只能有一个任务访问其内部状态**。这避免了数据竞争，但也会导致性能影响。

```swift
actor Counter {
    private var count = 0

    func increment() {
        count += 1
    }

    func getCount() -> Int {
        return count
    }
}

// 多个任务并发调用
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
    print("最终计数: \(finalCount)")  // 正确输出 10
}
```

### Sendable 类型

Actor 只能包含 Sendable 类型的属性。常见的 Sendable 类型包括：

- **值类型**：struct、enum、tuple（前提是内部内容也是 Sendable）
- **常量类**：let 修饰的 class，且不包含可变状态
- **actor**：所有 actor 都是 Sendable

```swift
// Sendable 类型可以安全在线程间传递
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
```

### nonisolated 关键字

有时我们需要在 Actor 中定义一些**不需要线程安全**的代码，比如：

1. **只读计算**：只读取值，不修改状态
2. **与其他类型无关**：不访问 Actor 内部状态

这时可以使用 `nonisolated` 关键字：

```swift
actor Logger {
    private var logs: [String] = []

    func log(_ message: String) {
        logs.append(message)
    }

    // 不访问 Actor 内部状态，可以使用 nonisolated
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
    print("时间戳: \(logger.timestamp)")  // 不需要 await
}
```

**注意**：nonisolated 的代码不能访问 Actor 内部的 mutable 属性。

### Actor 之间的通信

Actor 之间可以相互调用，但需要使用 await：

```swift
actor DataManager {
    private var data: [String] = []

    func add(_ item: String) {
        data.append(item)
    }

    func getAll() -> [String] {
        return data
    }

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
```

---

## 关键代码详解

### BankAccount Actor

```swift
actor BankAccount {
    private var balance: Double = 0

    func deposit(_ amount: Double) {
        balance += amount
        print("存款: \(amount), 余额: \(balance)")
    }
}
```

- `private var balance`：私有属性，外部无法直接访问
- `func deposit`：存款方法，自动在 Actor 内部同步执行
- 外部调用时需要 `await account.deposit(1000)`

### Counter Actor 与 TaskGroup

```swift
await withTaskGroup(of: Void.self) { group in
    for _ in 0..<10 {
        group.addTask {
            await counter.increment()
        }
    }
}
```

- `withTaskGroup` 创建任务组
- `addTask` 添加并发任务
- Actor 保证即使 10 个任务同时调用 increment，最终结果也是正确的 10

---

## 总结

Actor 是 Swift 并发编程的核心：

1. **线程安全**：自动处理互斥访问，避免数据竞争
2. **简单易用**：无需手动加锁，使用 await 即可
3. **消息传递**：Actor 之间通过异步消息通信
4. **Sendable**：确保数据在线程间安全传递

在实际开发中，对于需要共享可变状态的情况，优先使用 Actor 而不是传统的锁机制。
