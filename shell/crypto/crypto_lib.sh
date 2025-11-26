#!/bin/bash

# ==============================================================================
# 加密库 - crypto_lib.sh
# 功能：提供加密解密核心功能的 Bash 函数库
# 依赖：openssl
# 作者：重构版
# 日期：$(date +"%Y-%m-%d")
# ==============================================================================

# ------------------------------------------------------------------------------
# 全局常量定义
# ------------------------------------------------------------------------------
readonly AES_MODE="aes-256-cbc"  # 使用 CBC 模式以确保更好的兼容性
readonly KEY_LENGTH=32            # AES-256 需要 32 字节密钥
readonly IV_LENGTH=16             # CBC 模式需要 16 字节 IV
readonly PBKDF2_ITERATIONS=10000  # PBKDF2 迭代次数
readonly SALT_LENGTH=8            # 盐值长度（字节）
readonly HASH_ALGORITHM="sha256"   # 哈希算法

# ------------------------------------------------------------------------------
# 日志级别常量
# ------------------------------------------------------------------------------
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_ERROR=2

# 当前日志级别（默认：DEBUG）
LOG_LEVEL=${LOG_LEVEL_ERROR}

# ==============================================================================
# 工具函数
# ==============================================================================

# ------------------------------------------------------------------------------
# 日志函数
# 参数：
#   $1 - 日志级别 (0=DEBUG, 1=INFO, 2=ERROR)
#   $2 - 日志消息
# 返回值：无
# ------------------------------------------------------------------------------
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local level_str=""
    
    case "$level" in
        $LOG_LEVEL_DEBUG)
            level_str="[DEBUG]"
            ;;
        $LOG_LEVEL_INFO)
            level_str="[INFO]"
            ;;
        $LOG_LEVEL_ERROR)
            level_str="[ERROR]"
            ;;
        *)
            level_str="[UNKNOWN]"
            ;;
    esac
    
    # 只有当日志级别大于或等于当前设置时才输出
    if [[ "$level" -ge "$LOG_LEVEL" ]]; then
        if [[ "$level" -eq "$LOG_LEVEL_ERROR" ]]; then
            echo "$timestamp $level_str $message" >&2
        else
            echo "$timestamp $level_str $message" >&2
        fi
    fi
}

# ------------------------------------------------------------------------------
# 检查依赖工具是否安装
# 参数：无
# 返回值：
#   0 - 所有依赖已安装
#   1 - 缺少依赖
# ------------------------------------------------------------------------------
check_dependencies() {
    if ! command -v openssl &> /dev/null; then
        log_message $LOG_LEVEL_ERROR "错误: openssl 命令未找到，请安装 openssl"
        return 1
    fi
    
    return 0
}

# ------------------------------------------------------------------------------
# 检查密钥是否有效
# 参数：
#   $1 - 密钥字符串
# 返回值：
#   0 - 密钥有效
#   1 - 密钥无效
# ------------------------------------------------------------------------------
validate_key() {
    local key="$1"
    
    if [[ -z "$key" ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 密钥不能为空"
        return 1
    fi
    
    # 密钥长度检查（至少8个字符）
    if [[ ${#key} -lt 8 ]]; then
        log_message $LOG_LEVEL_WARNING "警告: 密钥长度小于8个字符，建议使用更长的密钥"
    fi
    
    return 0
}

# ------------------------------------------------------------------------------
# 生成随机盐值
# 参数：
#   $1 - 盐值长度（字节，可选，默认8字节）
# 返回值：
#   十六进制格式的盐值字符串
# ------------------------------------------------------------------------------
generate_salt() {
    local salt_length=${1:-$SALT_LENGTH}
    
    # 使用 openssl 生成随机字节并转换为十六进制
    local salt=$(openssl rand -hex "$salt_length")
    
    log_message $LOG_LEVEL_DEBUG "生成的盐值: ${salt:0:8}... (长度: $salt_length 字节)"
    echo "$salt"
}

# ------------------------------------------------------------------------------
# 直接从盐值和密码生成密钥的函数
# 参数：
#   $1 - 密码
#   $2 - 盐值
#   $3 - 迭代次数（可选，默认使用PBKDF2_ITERATIONS）
# 返回值：
#   十六进制格式的密钥字符串
# ------------------------------------------------------------------------------
generate_key_from_salt_and_password() {
    local password="$1"
    local salt="$2"
    local iterations=${3:-$PBKDF2_ITERATIONS}
    
    # 验证参数
    if [[ -z "$password" || -z "$salt" ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 密码或盐值为空"
        return 1
    fi
    
    # 使用PBKDF2派生密钥材料（只需要密钥部分，不需要IV）
    local key_material
    key_material=$(echo -n "$password" | \
        openssl dgst -sha256 -hmac "$salt" -binary 2>/dev/null | xxd -p)
    
    if [[ -z "$key_material" ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 密钥生成失败"
        return 1
    fi
    
    # 确保密钥长度为64个字符（32字节）
    local key="${key_material:0:64}"
    
    # 如果密钥不够长，用哈希值填充
    if [[ ${#key} -lt 64 ]]; then
        local padding=$(echo -n "$key$salt" | openssl dgst -sha256 -hex 2>/dev/null)
        key="$key${padding:0:64-${#key}}"
    fi
    
    log_message $LOG_LEVEL_DEBUG "密钥生成成功，长度: ${#key} 字符"
    echo "$key"
    return 0
}

# ------------------------------------------------------------------------------
# 从密码派生密钥和IV
# 参数：
#   $1 - 密码
#   $2 - 盐值 (十六进制)
# 返回值：
#   格式为 "派生密钥:IV" 的字符串（均为十六进制格式）
# ------------------------------------------------------------------------------
derive_key_and_iv() {
    local password="$1"
    local salt="$2"
    
    # 验证输入参数
    if [[ -z "$password" || -z "$salt" ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 密码和盐值不能为空"
        return 1
    fi
    
    # 使用简单可靠的方式生成密钥材料
    # 生成足够长的密钥材料（至少需要 64 + 32 = 96 个十六进制字符）
    local key_material=""
    local round=0
    local max_rounds=3  # 最多尝试3轮
    
    while [[ ${#key_material} -lt $(((KEY_LENGTH + IV_LENGTH) * 2)) && $round -lt $max_rounds ]]; do
        local current_input="$password$salt$round"
        local round_data
        round_data=$(echo -n "$current_input" | openssl dgst -"$HASH_ALGORITHM" -binary 2>/dev/null | xxd -p -c 64)
        key_material="$key_material$round_data"
        round=$((round + 1))
        log_message $LOG_LEVEL_DEBUG "密钥材料轮次 $round: 长度 ${#round_data}, 累计长度 ${#key_material}"
    done
    
    # 验证密钥材料长度
    if [[ ${#key_material} -lt $(((KEY_LENGTH + IV_LENGTH) * 2)) ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 无法生成足够长的密钥材料"
        log_message $LOG_LEVEL_DEBUG "生成的密钥材料长度: ${#key_material}, 需要: $(((KEY_LENGTH + IV_LENGTH) * 2))"
        return 1
    fi
    
    # 截取密钥和IV
    local key="${key_material:0:$((KEY_LENGTH * 2))}"  # 密钥：32字节 = 64个十六进制字符
    local iv="${key_material:$((KEY_LENGTH * 2)):$((IV_LENGTH * 2))}"  # IV：16字节 = 32个十六进制字符
    
    log_message $LOG_LEVEL_DEBUG "密钥长度: ${#key} 字符 (${KEY_LENGTH} 字节)"
    log_message $LOG_LEVEL_DEBUG "IV长度: ${#iv} 字符 (${IV_LENGTH} 字节)"
    log_message $LOG_LEVEL_DEBUG "密钥前8字符: ${key:0:8}"
    log_message $LOG_LEVEL_DEBUG "IV前8字符: ${iv:0:8}"
    
    # 确保IV不为空
    if [[ -z "$iv" ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 生成的IV为空"
        return 1
    fi
    
    # 返回格式：key:iv
    echo "$key:$iv"
    return 0
}

# ==============================================================================
# 核心加密解密函数
# ==============================================================================

# ------------------------------------------------------------------------------
# 加密数据
# 参数：
#   $1 - 明文数据
#   $2 - 密钥（十六进制格式）
#   $3 - IV（十六进制格式）
# 返回值：
#   加密后的 Base64 字符串
#   如果加密失败，返回空字符串并设置非零退出码
# ------------------------------------------------------------------------------
encrypt_data() {
    local plaintext="$1"
    local key="$2"
    local iv="$3"
    
    # 验证输入参数
    if [[ -z "$plaintext" || -z "$key" || -z "$iv" ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 加密数据、密钥和IV不能为空"
        return 1
    fi
    
    # 确保密钥和IV长度正确
    if [[ ${#key} -ne $((KEY_LENGTH * 2)) || ${#iv} -ne $((IV_LENGTH * 2)) ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 密钥或IV长度不正确"
        log_message $LOG_LEVEL_DEBUG "密钥长度: ${#key}, 期望: $((KEY_LENGTH * 2))"
        log_message $LOG_LEVEL_DEBUG "IV长度: ${#iv}, 期望: $((IV_LENGTH * 2))"
        return 1
    fi
    
    log_message $LOG_LEVEL_DEBUG "开始加密数据，长度: ${#plaintext} 字符"
    log_message $LOG_LEVEL_DEBUG "密钥: ${key:0:16}... (总长度: ${#key} 字符)"
    log_message $LOG_LEVEL_DEBUG "IV: ${iv:0:16}... (总长度: ${#iv} 字符)"
    
    # 使用PKCS#7填充（OpenSSL默认），并避免添加额外的换行符
    local encrypted_data
    encrypted_data=$(echo -n "$plaintext" | \
        openssl enc -aes-256-cbc -e -base64 -A -K "$key" -iv "$iv" 2>/dev/null)
    
    if [[ -z "$encrypted_data" ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 数据加密失败"
        return 1
    fi
    
    log_message $LOG_LEVEL_DEBUG "加密成功，结果长度: ${#encrypted_data} 字符"
    log_message $LOG_LEVEL_DEBUG "加密结果示例: ${encrypted_data:0:20}..."
    echo "$encrypted_data"
    return 0
}

# ------------------------------------------------------------------------------
# 解密数据
# 参数：
#   $1 - 加密数据（Base64 格式）
#   $2 - 密钥（十六进制格式）
#   $3 - IV（十六进制格式）
# 返回值：
#   解密后的明文数据
#   如果解密失败，返回空字符串并设置非零退出码
# ------------------------------------------------------------------------------
decrypt_data() {
    local encrypted_data="$1"
    local key="$2"
    local iv="$3"
    
    # 验证输入参数
    if [[ -z "$encrypted_data" || -z "$key" || -z "$iv" ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 加密数据、密钥和IV不能为空"
        return 1
    fi
    
    # 确保密钥和IV长度正确
    if [[ ${#key} -ne $((KEY_LENGTH * 2)) || ${#iv} -ne $((IV_LENGTH * 2)) ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 密钥或IV长度不正确"
        log_message $LOG_LEVEL_DEBUG "密钥长度: ${#key}, 期望: $((KEY_LENGTH * 2))"
        log_message $LOG_LEVEL_DEBUG "IV长度: ${#iv}, 期望: $((IV_LENGTH * 2))"
        return 1
    fi
    
    # 检查Base64格式是否有效
    if ! echo -n "$encrypted_data" | base64 -d 2>/dev/null >/dev/null; then
        log_message $LOG_LEVEL_ERROR "错误: 加密数据格式错误，不是有效的Base64编码"
        return 1
    fi
    
    log_message $LOG_LEVEL_DEBUG "开始解密数据，长度: ${#encrypted_data} 字符"
    log_message $LOG_LEVEL_DEBUG "密钥: ${key:0:16}... (总长度: ${#key} 字符)"
    log_message $LOG_LEVEL_DEBUG "IV: ${iv:0:16}... (总长度: ${#iv} 字符)"
    log_message $LOG_LEVEL_DEBUG "加密数据示例: ${encrypted_data:0:20}..."
    
    # 使用-A选项确保正确处理Base64，避免换行符问题
    local decrypted_data
    local openssl_status
    
    # 执行解密命令并捕获状态码
    decrypted_data=$(echo -n "$encrypted_data" | \
        openssl enc -aes-256-cbc -d -base64 -A -K "$key" -iv "$iv" 2>/dev/null)
    openssl_status=$?
    
    # 严格验证：OpenSSL必须成功返回(退出码0)且解密数据不为空
    if [[ $openssl_status -eq 0 && -n "$decrypted_data" ]]; then
        # 解密成功，验证结果是否包含乱码或不可打印字符
        # 检查是否有大量不可打印字符，这通常表明解密失败
        local printable_chars=$(echo -n "$decrypted_data" | tr -cd '[:print:]\n' | wc -c)
        local total_chars=$(echo -n "$decrypted_data" | wc -c)
        
        # 如果非打印字符超过50%，认为解密可能失败
        if [[ $printable_chars -lt $((total_chars / 2)) ]]; then
            log_message $LOG_LEVEL_DEBUG "解密结果包含大量不可打印字符，可能是密钥错误"
            log_message $LOG_LEVEL_ERROR "错误: 数据解密失败，可能是密钥错误或数据损坏"
            return 1
        fi
        
        log_message $LOG_LEVEL_DEBUG "解密成功，结果长度: ${#decrypted_data} 字符"
        log_message $LOG_LEVEL_DEBUG "解密结果内容: '$decrypted_data'"
        echo -n "$decrypted_data"
        return 0
    else
        # 如果第一次尝试失败，尝试使用-nopad选项（处理某些特殊情况）
        log_message $LOG_LEVEL_DEBUG "尝试使用-nopad选项解密"
        decrypted_data=$(echo -n "$encrypted_data" | \
            openssl enc -aes-256-cbc -d -base64 -A -K "$key" -iv "$iv" -nopad 2>/dev/null)
        openssl_status=$?
        
        # 对nopad选项也进行严格验证
        if [[ $openssl_status -eq 0 && -n "$decrypted_data" ]]; then
            # 检查不可打印字符比例
            local printable_chars=$(echo -n "$decrypted_data" | tr -cd '[:print:]\n' | wc -c)
            local total_chars=$(echo -n "$decrypted_data" | wc -c)
            
            if [[ $printable_chars -lt $((total_chars / 2)) ]]; then
                log_message $LOG_LEVEL_DEBUG "nopad解密结果包含大量不可打印字符，可能是密钥错误"
                log_message $LOG_LEVEL_ERROR "错误: 数据解密失败，可能是密钥错误或数据损坏"
                return 1
            fi
            
            log_message $LOG_LEVEL_DEBUG "使用-nopad解密成功，结果长度: ${#decrypted_data} 字符"
            echo -n "$decrypted_data"
            return 0
        else
            log_message $LOG_LEVEL_ERROR "错误: 数据解密失败，可能是密钥错误或数据损坏"
            return 1
        fi
    fi
}

# ==============================================================================
# 初始化函数
# ==============================================================================

# ------------------------------------------------------------------------------
# 库初始化
# 在加载库时自动执行
# 返回值：
#   0 - 初始化成功
#   1 - 初始化失败
# ------------------------------------------------------------------------------
init_crypto_lib() {
    # 检查依赖
    if ! check_dependencies; then
        return 1
    fi
    
    log_message $LOG_LEVEL_INFO "加密库初始化完成"
    log_message $LOG_LEVEL_DEBUG "使用的加密模式: $AES_MODE"
    log_message $LOG_LEVEL_DEBUG "密钥长度: $KEY_LENGTH 字节"
    log_message $LOG_LEVEL_DEBUG "IV长度: $IV_LENGTH 字节"
    log_message $LOG_LEVEL_DEBUG "PBKDF2迭代次数: $PBKDF2_ITERATIONS"
    
    return 0
}

# ==============================================================================
# 主程序（用于测试）
# 如果直接运行此脚本，则执行测试
# ==============================================================================
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # 初始化库
    if ! init_crypto_lib; then
        echo "初始化失败" >&2
        exit 1
    fi
    
    # 测试功能
    echo "=== 加密库测试 ==="
    
    # 生成测试用盐值
    test_salt=$(generate_salt)
    
    # 派生密钥和IV
    echo "派生密钥和IV测试..."
    key_iv=$(derive_key_and_iv "test_password" "$test_salt")
    key=${key_iv%%:*}
    iv=${key_iv#*:}
    
    echo "盐值: $test_salt"
    echo "密钥: ${key:0:16}... (长度: ${#key} 字符)"
    echo "IV: ${iv:0:16}... (长度: ${#iv} 字符)"
    
    # 测试加密
    test_plaintext="这是一段测试文本"
    echo "\n加密测试..."
    echo "明文: $test_plaintext"
    
    encrypted=$(encrypt_data "$test_plaintext" "$key" "$iv")
    echo "密文: $encrypted"
    
    # 测试解密
    echo "\n解密测试..."
    decrypted=$(decrypt_data "$encrypted" "$key" "$iv")
    echo "解密结果: $decrypted"
    
    # 验证结果
    if [[ "$decrypted" == "$test_plaintext" ]]; then
        echo "\n✅ 测试成功: 解密结果与明文一致"
        exit 0
    else
        echo "\n❌ 测试失败: 解密结果与明文不一致"
        exit 1
    fi
fi

# 自动初始化库
init_crypto_lib > /dev/null  # 静默初始化，不输出日志

# 成功加载库
export -f check_dependencies validate_key generate_salt derive_key_and_iv encrypt_data decrypt_data log_message
readonly CRYPTO_LIB_LOADED=1
