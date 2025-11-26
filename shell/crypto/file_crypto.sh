#!/bin/bash

# ==============================================================================
# 文件加密工具 - file_crypto.sh
# 功能：使用 AES-256-CBC 算法加密和解密文件
# 依赖：openssl、crypto_lib.sh
# 作者：重构版
# 日期：$(date +"%Y-%m-%d")
# ==============================================================================

# ------------------------------------------------------------------------------
# 全局变量和常量
# ------------------------------------------------------------------------------
readonly SCRIPT_NAME="file_crypto.sh"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CRYPTO_LIB="${SCRIPT_DIR}/crypto_lib.sh"

# 加密文件扩展名
readonly ENCRYPTED_EXTENSION=".encrypted"

# 操作模式
MODE_UNKNOWN=0
MODE_ENCRYPT=1
MODE_DECRYPT=2

# 当前操作模式
current_mode=$MODE_UNKNOWN

# 输入输出文件路径
input_file=""
output_file=""

# 用户提供的密钥
user_key=""

# 日志级别（可选，覆盖库的默认设置）
# LOG_LEVEL=${LOG_LEVEL_DEBUG}  # 取消注释启用调试日志

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

用法: $SCRIPT_NAME {encrypt|decrypt} [选项] <输入文件> <输出文件> [密钥]

功能: 使用 AES-256-CBC 算法加密或解密文件

命令:
  encrypt    加密文件
  decrypt    解密文件

选项:
  -h, --help  显示此帮助信息并退出

参数:
  <输入文件>  要加密或解密的文件路径
  <输出文件>  生成的输出文件路径
  [密钥]      可选，用于加密/解密的密钥（至少8个字符）。如果未提供，将交互式提示输入。

示例:
  # 方法1: 命令行提供密钥
  $SCRIPT_NAME encrypt plain.txt secret.bin "我的密钥"
  $SCRIPT_NAME decrypt secret.bin decrypted.txt "我的密钥"
  
  # 方法2: 交互式输入密钥
  $SCRIPT_NAME encrypt plain.txt secret.bin
  $SCRIPT_NAME decrypt secret.bin decrypted.txt

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
    if [[ $# -lt 3 ]]; then
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
    
    # 解析剩余参数
    if [[ $# -eq 3 ]]; then
        # 提供了3个参数：输入文件、输出文件、密钥
        input_file="$1"
        output_file="$2"
        user_key="$3"
        
        # 验证密钥
        if ! validate_key "$user_key"; then
            return 1
        fi
    elif [[ $# -eq 2 ]]; then
        # 只提供了2个参数：输入文件、输出文件（密钥将交互式获取）
        input_file="$1"
        output_file="$2"
        log_message $LOG_LEVEL_DEBUG "未在命令行提供密钥，将在交互式模式下获取"
    else
        echo "错误: 参数数量不正确" >&2
        show_help
        return 1
    fi
    
    # 验证输入文件是否存在
    if [[ ! -f "$input_file" ]]; then
        echo "错误: 输入文件 '$input_file' 不存在" >&2
        return 1
    fi
    
    # 检查输出文件是否已存在
    if [[ -f "$output_file" ]]; then
        echo "警告: 输出文件 '$output_file' 已存在，将被覆盖" >&2
    fi
    
    log_message $LOG_LEVEL_DEBUG "解析命令行参数成功"
    log_message $LOG_LEVEL_DEBUG "模式: $([[ $current_mode -eq $MODE_ENCRYPT ]] && echo "加密" || echo "解密")"
    log_message $LOG_LEVEL_DEBUG "输入文件: $input_file"
    log_message $LOG_LEVEL_DEBUG "输出文件: $output_file"
    
    return 0
}

# ------------------------------------------------------------------------------
# 加密文件
# 参数：无（使用全局变量）
# 返回值：
#   0 - 加密成功
#   1 - 加密失败
# ------------------------------------------------------------------------------
encrypt_file() {
    log_message $LOG_LEVEL_INFO "开始加密文件: $input_file"
    
    # 生成盐值
    local salt=$(generate_salt)
    if [[ $? -ne 0 ]]; then
        log_message $LOG_LEVEL_ERROR "生成盐值失败"
        return 1
    fi
    
    # 派生密钥和IV
    local key_iv=$(derive_key_and_iv "$user_key" "$salt")
    if [[ $? -ne 0 ]]; then
        log_message $LOG_LEVEL_ERROR "派生密钥和IV失败"
        return 1
    fi
    
    # 解析密钥和IV
    local key=${key_iv%%:*}
    local iv=${key_iv#*:}
    
    # 读取输入文件内容（使用base64编码处理二进制数据）
    local plaintext_base64
    plaintext_base64=$(base64 < "$input_file" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log_message $LOG_LEVEL_ERROR "读取输入文件失败"
        return 1
    fi
    
    # 加密数据
    local encrypted_output
    encrypted_output=$(encrypt_data "$plaintext_base64" "$key" "$iv")
    if [[ $? -ne 0 || -z "$encrypted_output" ]]; then
        log_message $LOG_LEVEL_ERROR "文件加密过程失败"
        return 1
    fi
    
    # 写入输出文件（格式: salt:iv:encrypted_data）
    echo "$salt:$iv:$encrypted_output" > "$output_file" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        log_message $LOG_LEVEL_ERROR "写入输出文件失败"
        return 1
    fi
    
    log_message $LOG_LEVEL_INFO "文件加密成功，输出至: $output_file"
    return 0
}

# ------------------------------------------------------------------------------
# 解密文件
# 参数：无（使用全局变量）
# 返回值：
#   0 - 解密成功
#   1 - 解密失败
# ------------------------------------------------------------------------------
decrypt_file() {
    log_message $LOG_LEVEL_INFO "开始解密文件: $input_file"
    
    # 读取输入文件内容
    local encrypted_input
    encrypted_input=$(cat "$input_file" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log_message $LOG_LEVEL_ERROR "读取输入文件失败"
        return 1
    fi
    
    # 验证输入格式并分割数据
    if [[ ! "$encrypted_input" =~ ^[0-9a-fA-F]+:[0-9a-fA-F]+:.+ ]]; then
        log_message $LOG_LEVEL_ERROR "错误: 加密数据格式不正确，应为 'salt:iv:encrypted_data'"
        return 1
    fi
    
    # 提取 salt、iv 和加密数据
    local salt="${encrypted_input%%:*}"
    local remaining="${encrypted_input#*:}"
    local iv="${remaining%%:*}"
    local encrypted_data="${remaining#*:}"
    
    # 派生密钥（使用相同的盐值和IV）
    # 注意：这里我们已经有了IV，所以只需要验证密钥派生是否正确
    local key_iv=$(derive_key_and_iv "$user_key" "$salt")
    if [[ $? -ne 0 ]]; then
        log_message $LOG_LEVEL_ERROR "派生密钥失败，可能是密钥错误"
        return 1
    fi
    
    # 解析密钥
    local key=${key_iv%%:*}
    
    # 解密数据
    local plaintext_base64
    plaintext_base64=$(decrypt_data "$encrypted_data" "$key" "$iv")
    if [[ $? -ne 0 || -z "$plaintext_base64" ]]; then
        log_message $LOG_LEVEL_ERROR "文件解密过程失败，可能是密钥错误或数据损坏"
        return 1
    fi
    
    # 解码并写入输出文件
    echo -n "$plaintext_base64" | base64 -d > "$output_file" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        log_message $LOG_LEVEL_ERROR "写入输出文件失败"
        return 1
    fi
    
    log_message $LOG_LEVEL_INFO "文件解密成功，输出至: $output_file"
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
    
    # 交互式获取密钥
    get_key_interactively() {
        # 提示用户输入密钥（隐藏输入）
        echo -n "请输入密钥（至少8个字符）: " >&2
        read -s user_key
        echo >&2  # 换行
        
        # 验证密钥
        if ! validate_key "$user_key"; then
            return 1
        fi
        
        return 0
    }
    
    # 如果未提供密钥，交互式获取
    if [[ -z "$user_key" ]]; then
        if ! get_key_interactively; then
            echo "密钥获取失败！" >&2
            exit 1
        fi
    fi
    
    # 执行相应的操作
    case "$current_mode" in
        $MODE_ENCRYPT)
            if ! encrypt_file; then
                echo "加密失败！请检查输入文件、权限或密钥" >&2
                exit 1
            fi
            ;;
        $MODE_DECRYPT)
            if ! decrypt_file; then
                echo "解密失败！可能是密钥错误或数据损坏" >&2
                exit 1
            fi
            ;;
        *)
            log_message $LOG_LEVEL_ERROR "未知的操作模式"
            echo "错误: 未知的操作模式" >&2
            exit 1
            ;;
    esac
    
    # 成功完成
    echo "操作成功完成！" >&2
    return 0
}

# 执行主程序
main "$@"
