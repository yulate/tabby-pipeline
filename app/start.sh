#!/bin/bash

# 手动将 Neo4j 的 bin 目录添加到 PATH 中
export PATH=/var/lib/neo4j/bin:$PATH

# 简化版 Tabby 启动脚本，避免权限问题
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
JAVA_OPTS="-Xmx16g -Xms4g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
NEO4J_HOST="localhost"
NEO4J_PORT="7687"
NEO4J_HTTP_PORT="7474"
MAX_WAIT_TIME=300
HEALTH_CHECK_INTERVAL=5

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 清理函数
cleanup() {
    log_info "执行清理操作..."
    if [ ! -z "$NEO4J_PID" ]; then
        log_info "停止 Neo4j 进程 (PID: $NEO4J_PID)"
        kill -TERM "$NEO4J_PID" 2>/dev/null || true
        wait "$NEO4J_PID" 2>/dev/null || true
    fi
}

trap cleanup INT TERM

# 检查端口连通性
check_port() {
    local host=$1
    local port=$2
    nc -z "$host" "$port" 2>/dev/null
}

# 设置 Neo4j 环境
setup_neo4j() {
    log_step "配置 Neo4j 环境..."
    
    # 创建必要目录
    mkdir -p /app/logs /app/reports
    
    # 拷贝插件（忽略权限错误）
    log_info "拷贝插件到 Neo4j..."
    cp /app/plugins/*.jar /var/lib/neo4j/plugins/ 2>/dev/null || true
    
    # 拷贝配置文件（忽略权限错误）
    log_info "拷贝配置文件到 Neo4j..."
    cp /app/config/* /var/lib/neo4j/conf/ 2>/dev/null || true
    
    log_info "Neo4j 环境配置完成"
}

# 启动 Neo4j
start_neo4j() {
    log_step "启动 Neo4j 服务..."
    
    # 直接启动 Neo4j
    cd /var/lib/neo4j
    nohup /startup/docker-entrypoint.sh neo4j > /app/logs/neo4j.log 2>&1 &
    NEO4J_PID=$!
    
    log_info "Neo4j 服务已启动，PID: $NEO4J_PID"
    
    # 等待 Neo4j 启动
    log_info "等待 Neo4j 启动..."
    local wait_time=0
    
    while [ $wait_time -lt $MAX_WAIT_TIME ]; do
        if ! kill -0 "$NEO4J_PID" 2>/dev/null; then
            log_error "Neo4j 进程已停止"
            cat /app/logs/neo4j.log
            exit 1
        fi
        
        if check_port "$NEO4J_HOST" "$NEO4J_PORT" && check_port "$NEO4J_HOST" "$NEO4J_HTTP_PORT"; then
            log_info "Neo4j 启动成功！"
            sleep 10  # 额外等待确保完全启动
            break
        fi
        
        sleep $HEALTH_CHECK_INTERVAL
        wait_time=$((wait_time + HEALTH_CHECK_INTERVAL))
    done
    
    if [ $wait_time -ge $MAX_WAIT_TIME ]; then
        log_error "Neo4j 启动超时"
        cat /app/logs/neo4j.log
        exit 1
    fi
}

# 【新增】创建 Neo4j 索引和约束的函数
create_neo4j_schema() {
    log_step "创建 Neo4j 索引和约束..."
    
    # 等待一小段时间确保数据库完全准备好接受查询
    sleep 5 

    # 使用 cypher-shell 执行 Cypher 语句
    # NEO4J_USER 和 NEO4J_PASSWORD 环境变量由 Dockerfile 提供
    if cypher-shell -u "$Tabby_NEO4J_USER" -p "$Tabby_NEO4J_PASSWORD" <<EOF
CREATE CONSTRAINT c1 IF NOT EXISTS FOR (c:Class) REQUIRE c.ID IS UNIQUE;
CREATE CONSTRAINT c2 IF NOT EXISTS FOR (c:Class) REQUIRE c.NAME IS UNIQUE;
CREATE CONSTRAINT c3 IF NOT EXISTS FOR (m:Method) REQUIRE m.ID IS UNIQUE;
CREATE CONSTRAINT c4 IF NOT EXISTS FOR (m:Method) REQUIRE m.SIGNATURE IS UNIQUE;
CREATE INDEX index1 IF NOT EXISTS FOR (m:Method) ON (m.NAME);
CREATE INDEX index2 IF NOT EXISTS FOR (m:Method) ON (m.CLASSNAME);
CREATE INDEX index3 IF NOT EXISTS FOR (m:Method) ON (m.NAME, m.CLASSNAME);
CREATE INDEX index4 IF NOT EXISTS FOR (m:Method) ON (m.NAME, m.NAME0);
CREATE INDEX index5 IF NOT EXISTS FOR (m:Method) ON (m.SIGNATURE);
CREATE INDEX index6 IF NOT EXISTS FOR (m:Method) ON (m.NAME0);
EOF
    then
        log_info "Neo4j 索引和约束创建成功。"
    else
        log_error "Neo4j 索引和约束创建失败。"
        exit 1
    fi
}

# 运行 Tabby 分析
run_tabby_analysis() {
    log_step "运行 Tabby 代码分析..."
    
    cd /app/tabby
    
    # 备份旧输出
    if [ -d "output" ]; then
        mv output "output_backup_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi
    
    log_info "开始执行 Tabby 代码分析..."
    local start_time=$(date +%s)
    
    if java $JAVA_OPTS -jar ./tabby.jar; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_info "Tabby 代码分析完成，耗时: ${duration}s"
    else
        log_error "Tabby 代码分析失败"
        exit 1
    fi
}

# 运行漏洞发现
run_vul_finder() {
    log_step "运行 Tabby 漏洞发现..."
    
    cd /app/tabby
    
    if [ ! -d "output/dev" ]; then
        log_error "分析输出目录不存在: output/dev"
        exit 1
    fi
    
    log_info "开始执行漏洞发现..."
    local start_time=$(date +%s)
    
    # 修正了调用参数
    if java $JAVA_OPTS -jar tabby-vul-finder.jar --load output/dev; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_info "漏洞发现完成，耗时: ${duration}s"
    else
        log_error "漏洞发现失败"
        exit 1
    fi
}

# 生成报告
generate_report() {
    log_step "生成分析报告..."
    
    local report_file="/app/reports/analysis_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "Tabby 代码分析报告"
        echo "===================="
        echo "生成时间: $(date)"
        echo ""
        echo "输出文件："
        find /app/tabby/output -type f 2>/dev/null | head -20
        echo ""
        echo "Neo4j 状态: $(if kill -0 $NEO4J_PID 2>/dev/null; then echo '运行中'; else echo '已停止'; fi)"
        echo "Java 版本: $(java -version 2>&1 | head -1)"
    } > "$report_file"
    
    log_info "报告已生成: $report_file"
}

# 显示服务状态
show_status() {
    log_info "=========================================="
    log_info "           服务状态"
    log_info "=========================================="
    log_info "Neo4j HTTP: http://localhost:7474"
    log_info "Neo4j Bolt: bolt://localhost:7687"
    log_info "用户名: neo4j, 密码: password"
    log_info "Tabby 输出: /app/tabby/output"
    log_info "分析报告: /app/reports/"
    log_info "=========================================="
}

# 保持服务运行
keep_running() {
    log_info "容器将持续运行..."
    
    while true; do
        # 检查 Neo4j 是否还在运行
        if [ ! -z "$NEO4J_PID" ] && ! kill -0 "$NEO4J_PID" 2>/dev/null; then
            log_warn "Neo4j 进程已停止，尝试重启..."
            start_neo4j
        fi
        
        sleep 60  # 每分钟检查一次
    done
}

# 主函数
main() {
    log_info "=========================================="
    log_info "     启动 Tabby 完整分析流程"
    log_info "=========================================="
    
    setup_neo4j
    start_neo4j
    create_neo4j_schema # 【修改】在这里调用新函数
    run_tabby_analysis
    run_vul_finder
    generate_report
    
    log_info "=========================================="
    log_info "     分析流程完成！"
    log_info "=========================================="
    
    show_status
    keep_running
}

# 执行主函数
main "$@"