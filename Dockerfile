FROM neo4j:5.26.0

# 维护者信息
LABEL maintainer="tabby-pipeline"
LABEL description="Tabby static analysis tool with Neo4j integration"

# 安装必要的系统工具和 JDK
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk \
    git \
    curl \
    wget \
    unzip \
    python3 \
    python3-pip \
    maven \
    procps \
    sudo \
    netcat-traditional \
    && rm -rf /var/lib/apt/lists/*

RUN echo "neo4j ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# 安装 Python 依赖
RUN pip3 install neo4j requests flask

# 设置 Java 环境变量
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# 创建必要的目录，全部使用 root
RUN mkdir -p /app/tabby \
    && mkdir -p /app/logs \
    && mkdir -p /app/reports \
    && mkdir -p /app/tabby/source \
    && mkdir -p /work \
    && mkdir -p /var/lib/neo4j/plugins \
    && mkdir -p /var/lib/neo4j/conf \
    && mkdir -p /var/lib/neo4j/data \
    && mkdir -p /var/lib/neo4j/logs

# 复制应用文件
COPY app/ /app/

# 复制 Neo4j 配置文件
COPY app/config/neo4j.conf /var/lib/neo4j/conf/neo4j.conf
COPY app/config/apoc.conf /var/lib/neo4j/conf/apoc.conf

# 复制 Neo4j 插件
COPY app/plugins/*.jar /var/lib/neo4j/plugins/

# 复制 Tabby 应用程序
COPY app/tabby/ /app/tabby/

# 复制启动脚本
COPY app/start.sh /app/start.sh

# 将所有权交给 neo4j 用户
RUN chown -R neo4j:neo4j /app /work /var/lib/neo4j

# 设置权限 - 只设置必要的执行权限
RUN chmod +x /app/start.sh \
    && chmod +x /app/tabby/run.sh 2>/dev/null || true \
    && chmod -R 755 /var/lib/neo4j \
    && chmod 777 /app

# 设置环境变量
ENV NEO4J_HOME=/var/lib/neo4j
ENV Tabby_NEO4J_URI=bolt://localhost:7687
ENV Tabby_NEO4J_USER=neo4j
ENV Tabby_NEO4J_PASSWORD=password
ENV TABBY_HOME=/app/tabby

# 暴露端口
EXPOSE 7474 7687

# 工作目录
WORKDIR /app

# 启动脚本
CMD ["/app/start.sh"]