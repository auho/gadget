#!/bin/bash

# ==============================================================================
# 文本加密工具 - text_crypto.sh
# 功能：使用 AES-256-CBC 算法加密和解密文本数据
# 依赖：openssl、crypto_lib.sh
# 作者：重构版
# 日期：$(date +"%Y-%m-%d")
# ==============================================================================

# ------------------------------------------------------------------------------
# 全局变量和常量
# ------------------------------------------------------------------------------
readonly SCRIPT_NAME="text_crypto.sh"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CRYPTO_LIB="${SCRIPT_DIR}/crypto_lib.sh"

# 操作模式
MODE_UNKNOWN=0
MODE_ENCRYPT=1
MODE_DECRYPT=2

# 当前操作模式
current_mode=$MODE_UNKNOWN

# 用户提供的密钥
user_key=""

# 日志级别（生产环境使用ERROR级别）
LOG_LEVEL=${LOG_LEVEL_ERROR}  # 使用ERROR级别减少输出

# ==============================================================================
# 函数定义
# ==============================================================================

# ------------------------------------------------------------------------------
# 显示使用帮助信息
# 参数：无
# 返回值：无
# ------------------------------------------------------------------------------
show_help() {
    cat << EOF

用法: $SCRIPT_NAME {encrypt|decrypt} [选项] [密钥]

功能: 使用 AES-256-CBC 算法加密或解密文本数据

命令:
  encrypt    加密文本（从标准输入读取文本或交互式输入，输出加密结果）
  decrypt    解密文本（从标准输入读取加密文本或交互式输入，输出解密结果）

选项:
  -h, --help  显示此帮助信息并退出

参数:
  [密钥]  可选，用于加密/解密的密钥（至少8个字符）。如果未提供，将交互式提示输入。

示例:
  # 方法1: 命令行提供密钥，管道提供数据
  echo "明文文本" | $SCRIPT_NAME encrypt "我的密钥"
  echo "salt:iv:encrypted_data" | $SCRIPT_NAME decrypt "我的密钥"
  
  # 方法2: 交互式输入（不提供密钥和管道数据）
  $SCRIPT_NAME encrypt
  $SCRIPT_NAME decrypt

EOF
}

# ------------------------------------------------------------------------------
# 加载加密库
# 参数：无
# 返回值：
#   0 - 加载成功
#   1 - 加载失败
# ------------------------------------------------------------------------------
load_crypto_lib() {
    if [[ ! -f "$CRYPTO_LIB" ]]; then
        echo "错误: 找不到加密库文件 '$CRYPTO_LIB'" >&2
        return 1
    fi
    
    # 加载加密库
    source "$CRYPTO_LIB"
    
    # 检查库是否成功加载
    if [[ -z "$CRYPTO_LIB_LOADED" ]]; then
        echo "错误: 加密库加载失败" >&2
        return 1
    fi
    
    log_message $LOG_LEVEL_INFO "加密库加载成功"
    return 0
}

# ------------------------------------------------------------------------------
# 解析命令行参数
# 参数：
#   $@ - 命令行参数
# 返回值：
#   0 - 解析成功
#   1 - 解析失败
# ------------------------------------------------------------------------------
parse_arguments() {
    local cmd=""
    
    # 检查参数数量
    if [[ $# -lt 1 ]]; then
        show_help
        return 1
    fi
    
    # 解析命令
    cmd="$1"
    shift
    
    case "$cmd" in
        encrypt)
            current_mode=$MODE_ENCRYPT
            ;;
        decrypt)
            current_mode=$MODE_DECRYPT
            ;;
        -h|--help)
            show_help
            return 1
            ;;
        *)
            echo "错误: 未知命令 '$cmd'" >&2
            show_help
            return 1
            ;;
    esac
    
    # 检查是否提供了密钥
    if [[ $# -eq 1 ]]; then
        user_key="$1"
        
        # 验证密钥
        if ! validate_key "$user_key"; then
            return 1
        fi
    else
        # 未提供密钥，将在main函数中交互式获取
        log_message $LOG_LEVEL_DEBUG "未在命令行提供密钥，将在交互式模式下获取"
    fi
    
    # 检查标准输入
    if ! [[ -t 0 ]]; then
        # 有标准输入
        log_message $LOG_LEVEL_DEBUG "检测到标准输入"
    else
        # 无标准输入，将在main函数中交互式获取
        log_message $LOG_LEVEL_DEBUG "未检测到标准输入，将在交互式模式下获取文本"
    fi
    
    log_message $LOG_LEVEL_DEBUG "解析命令行参数成功"
    log_message $LOG_LEVEL_DEBUG "模式: $([[ $current_mode -eq $MODE_ENCRYPT ]] && echo "加密" || echo "解密")"
    
    return 0
}

# ------------------------------------------------------------------------------
# 加密文本
# 参数：
#   plaintext - 要加密的文本
# 返回值：
#   成功时输出加密结果（格式: salt:iv:encrypted_data）
#   失败时返回非零值
# ------------------------------------------------------------------------------
encrypt_text() {
    local plaintext="$1"
    log_message $LOG_LEVEL_INFO "开始文本加密处理"
    
    # 调试：检查明文
    log_message $LOG_LEVEL_DEBUG "明文长度: ${#plaintext}"
    log_message $LOG_LEVEL_DEBUG "明文内容: $plaintext"
    
    # 生成盐值
    local salt=$(generate_salt)
    if [[ $? -ne 0 ]]; then
        log_message $LOG_LEVEL_ERROR "生成盐值失败"
        return 1
    fi
    log_message $LOG_LEVEL_DEBUG "盐值: $salt"
    
    # 派生密钥和IV
    local key_iv=$(derive_key_and_iv "$user_key" "$salt")
    local derive_exit_code=$?
    log_message $LOG_LEVEL_DEBUG "密钥派生结果: '$key_iv'"
    log_message $LOG_LEVEL_DEBUG "密钥派生退出码: $derive_exit_code"
    
    if [[ $derive_exit_code -ne 0 || -z "$key_iv" ]]; then
        log_message $LOG_LEVEL_ERROR "派生密钥和IV失败或结果为空"
        return 1
    fi
    
    # 解析密钥和IV
    local key=${key_iv%%:*}
    local iv=${key_iv#*:}
    
    # 调试：检查密钥和IV
    log_message $LOG_LEVEL_DEBUG "密钥长度: ${#key}"
    log_message $LOG_LEVEL_DEBUG "密钥内容: $key"
    log_message $LOG_LEVEL_DEBUG "IV长度: ${#iv}"
    log_message $LOG_LEVEL_DEBUG "IV内容: $iv"
    
    # 验证密钥和IV不为空
    if [[ -z "$key" || -z "$iv" ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 密钥或IV为空"
        return 1
    fi
    
    # 加密数据
    local encrypted_output
    encrypted_output=$(encrypt_data "$plaintext" "$key" "$iv")
    if [[ $? -ne 0 || -z "$encrypted_output" ]]; then
        log_message $LOG_LEVEL_ERROR "文本加密过程失败"
        return 1
    fi
    
    # 输出加密结果（格式: salt:iv:encrypted_data）
    echo "$salt:$iv:$encrypted_output"
    log_message $LOG_LEVEL_INFO "文本加密成功"
    return 0
}

# ------------------------------------------------------------------------------
# 解密文本
# 参数：
#   encrypted_input - 要解密的加密文本（格式: salt:iv:encrypted_data）
# 返回值：
#   成功时输出解密后的明文
#   失败时返回非零值
# ------------------------------------------------------------------------------
decrypt_text() {
    local encrypted_input="$1"
    log_message $LOG_LEVEL_INFO "开始文本解密处理"
    
    # 验证输入格式并分割数据
    if [[ ! "$encrypted_input" =~ ^[0-9a-fA-F]+:[0-9a-fA-F]+:.+ ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 加密数据格式不正确，应为 'salt:iv:encrypted_data'"
        echo "错误: 加密数据格式不正确，应为 'salt:iv:encrypted_data'" >&2
        return 1
    fi
    
    # 提取 salt、iv 和加密数据
    local salt="${encrypted_input%%:*}"
    local remaining="${encrypted_input#*:}"
    local iv="${remaining%%:*}"
    local encrypted_data="${remaining#*:}"
    
    log_message $LOG_LEVEL_DEBUG "提取的盐值: $salt"
    log_message $LOG_LEVEL_DEBUG "提取的IV: $iv"
    log_message $LOG_LEVEL_DEBUG "加密数据长度: ${#encrypted_data}"
    
    # 验证IV长度
    if [[ ${#iv} -ne 32 ]]; then
        log_message $LOG_LEVEL_ERROR "错误: IV长度必须为32字符"
        echo "解密失败: IV格式不正确" >&2
        return 1
    fi
    
    # 确保与加密过程使用完全相同的密钥生成逻辑
    local key_iv
    key_iv=$(derive_key_and_iv "$user_key" "$salt")
    local derive_exit_code=$?
    
    log_message $LOG_LEVEL_DEBUG "密钥派生结果: '$key_iv'"
    log_message $LOG_LEVEL_DEBUG "密钥派生退出码: $derive_exit_code"
    
    if [[ $derive_exit_code -ne 0 || -z "$key_iv" ]]; then
        log_message $LOG_LEVEL_ERROR "派生密钥和IV失败或结果为空，可能是密钥错误"
        echo "解密失败: 可能是密钥错误或数据格式不正确" >&2
        return 1
    fi
    
    # 解析密钥（使用派生的密钥，但保留输入中提取的IV）
    local key=${key_iv%%:*}
    
    # 调试：检查密钥和IV
    log_message $LOG_LEVEL_DEBUG "解密使用的密钥长度: ${#key}"
    log_message $LOG_LEVEL_DEBUG "解密使用的密钥内容: $key"
    log_message $LOG_LEVEL_DEBUG "解密使用的IV长度: ${#iv}"
    log_message $LOG_LEVEL_DEBUG "解密使用的IV内容: $iv"
    
    # 验证密钥和IV不为空
    if [[ -z "$key" || -z "$iv" ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 密钥或IV为空"
        echo "解密失败: 内部错误 - 密钥或IV为空" >&2
        return 1
    fi
    
    # 解密数据（确保使用正确的IV）
    local plaintext
    plaintext=$(decrypt_data "$encrypted_data" "$key" "$iv")
    if [[ $? -ne 0 || -z "$plaintext" ]]; then
        log_message $LOG_LEVEL_ERROR "文本解密过程失败，可能是密钥错误或数据损坏"
        echo "解密失败: 文本解密过程失败，可能是密钥错误或数据损坏" >&2
        return 1
    fi
    
    # 输出解密后的明文
    echo -n "$plaintext"
    log_message $LOG_LEVEL_INFO "文本解密成功"
    return 0
}

# ==============================================================================
# 主程序
# ==============================================================================

main() {
    # 加载加密库
    if ! load_crypto_lib; then
        exit 1
    fi
    
    # 解析命令行参数
    if ! parse_arguments "$@"; then
        exit 1
    fi
    
    # 读取标准输入
    # 交互式获取密钥
    get_key_interactively() {
        # 提示用户输入密钥（隐藏输入）
        echo -n "请输入密钥（至少8个字符）: " >&2
        # 在非终端模式下（如管道）不使用-s参数
        if [[ -t 0 ]]; then
            read -s user_key
        else
            read user_key
        fi
        echo >&2  # 换行
        
        # 验证密钥
        if ! validate_key "$user_key"; then
            return 1
        fi
        
        return 0
    }
    
    # 交互式获取文本
    get_text_interactively() {
        local mode=$1
        local prompt=""
        local input_text=""
        
        if [[ $mode -eq $MODE_ENCRYPT ]]; then
            prompt="请输入要加密的文本: "
        else
            prompt="请输入要解密的文本（格式: salt:iv:encrypted_data）: "
        fi
        
        echo -n "$prompt" >&2
        IFS= read -r input_text
        
        # 检查输入是否为空
        if [[ -z "$input_text" ]]; then
            echo "错误: 输入文本不能为空" >&2
            return 1
        fi
        
        echo "$input_text"
        return 0
    }
    
    # 读取输入文本和密钥（如果通过管道提供）
    local input_text
    if ! [[ -t 0 ]]; then
        # 从标准输入读取所有内容
        local all_input=$(cat - 2>/dev/null)
        if [[ $? -ne 0 || -z "$all_input" ]]; then
            echo "错误: 无法读取输入数据或输入为空" >&2
            exit 1
        fi
        
        # 分割第一行作为文本，第二行作为密钥（如果没有通过命令行提供密钥）
        input_text=$(echo "$all_input" | head -n 1)
        if [[ -z "$user_key" ]]; then
            user_key=$(echo "$all_input" | tail -n +2 | head -n 1)
            # 验证密钥
            if ! validate_key "$user_key"; then
                echo "密钥获取失败！" >&2
                exit 1
            fi
        fi
    else
        # 交互式获取文本（先获取文本）
        input_text=$(get_text_interactively "$current_mode")
        if [[ $? -ne 0 || -z "$input_text" ]]; then
            exit 1
        fi
        
        # 如果未提供密钥，交互式获取（后获取密码）
        if [[ -z "$user_key" ]]; then
            if ! get_key_interactively; then
                echo "密钥获取失败！" >&2
                exit 1
            fi
        fi
    fi
    
    # 执行相应的操作
    case "$current_mode" in
        $MODE_ENCRYPT)
            encrypt_text "$input_text"
            local exit_code=$?
            if [[ $exit_code -eq 0 ]]; then
                echo "文本加密成功！" >&2
            else
                echo "文本加密失败！" >&2
            fi
            exit $exit_code
            ;;
        $MODE_DECRYPT)
            decrypt_text "$input_text"
            local exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                echo "文本解密失败！可能是密钥错误或数据损坏" >&2
            fi
            exit $exit_code
            ;;
        *)
            log_message $LOG_LEVEL_ERROR "未知的操作模式"
            echo "错误: 未知的操作模式" >&2
            exit 1
            ;;
    esac
}

# 执行主程序
main "$@"
