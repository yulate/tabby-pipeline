# tabby-pipeline: 容器化tabby gadget流水线

集成了强大的代码分析工具 Tabby 与图数据库 Neo4j，将复杂的分析流程封装在一个简单易用的 Docker Compose 环境中，实现了“开箱即用”的代码分析与漏洞发现。

> A CAT called tabby ( Code Analysis Tool ): [tabby](https://github.com/wh1t3p1g/tabby)

![](https://p.ipic.vip/00dz8k.png)

## ✨ 项目特性
- 🚀 一键启动: 只需一条 docker-compose up 命令即可启动完整的分析环境，无需手动安装 Java, Neo4j, Python 或其他依赖。

- ⚙️ 自动化流程: 内置的 start.sh 脚本自动完成所有步骤：启动 Neo4j -> 创建数据库索引 -> 运行 Tabby 代码分析 -> 执行漏洞发现 -> 生成报告。

- ✍️ 数据持久化: 通过 Docker Volumes 持久化 Neo4j 数据库、分析产物和报告，即使容器被删除，您的宝贵数据依然安全无虞。

- 🌳 环境隔离: 所有依赖和服务都运行在 Docker 容器中，与您的主机环境完全隔离，干净又整洁。

## 📂 项目结构

```
.
├── app/                      # 应用程序核心目录
│   ├── config/               # 配置文件 (neo4j.conf, apoc.conf)
│   ├── plugins/              # Neo4j 插件
│   ├── tabby/                # Tabby 工具 (tabby.jar, tabby-vul-finder.jar)
│   └── start.sh              # 核心自动化流程脚本
├── pvc/  
│   ├── source/               # 【用户】请将您要分析的源代码放在这里
│   ├── reports/              # 【输出】生成的分析报告会保存在这里
│   ├── output/               # 【输出】Tabby 的详细分析产物会保存在这里
├── Dockerfile                # 用于构建分析环境的 Docker 镜像
└── docker-compose.yml        # 定义和运行多容器 Docker 应用程序的工具
```

## 🤝 贡献
欢迎任何形式的贡献！如果您有好的想法、发现了 Bug 或者想改进代码，请随时提交 Pull Request 或创建 Issue。

## 📄 开源许可
本项目采用 MIT License 开源许可。