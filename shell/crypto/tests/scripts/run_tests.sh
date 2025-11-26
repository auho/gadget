#!/bin/bash

# 加密工具测试脚本
# 功能：自动测试文本和文件加密解密功能
# 作者：Crypto Tool Project
# 日期：$(date +"%Y-%m-%d")

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 路径定义
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATA_DIR="$BASE_DIR/tests/data"
RESULTS_DIR="$BASE_DIR/tests/results"
LOG_FILE="$RESULTS_DIR/test_results.log"

# 创建结果目录
mkdir -p "$RESULTS_DIR"

# 初始化日志文件
echo "=========================================" > "$LOG_FILE"
echo "加密工具测试报告 - $(date)" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo -e "${YELLOW}开始运行加密工具测试...${NC}"
echo "测试开始时间: $(date)" >> "$LOG_FILE"

# 测试函数
test_text_encryption() {
    echo -e "\n${YELLOW}1. 测试文本加密解密功能${NC}"
    echo "\n1. 文本加密解密测试" >> "$LOG_FILE"
    
    # 测试文本
    TEST_TEXT="这是一个测试文本，包含中文和特殊字符！@#$%^&*()"
    TEST_PASSWORD="TestPassword123"
    
    # 加密
    echo -e "${GREEN}正在加密文本...${NC}"
    ENCRYPTED_RESULT=$(echo "$TEST_TEXT" | "$BASE_DIR/text_crypto.sh" encrypt "$TEST_PASSWORD")
    ENCRYPT_EXIT_CODE=$?
    
    echo "加密命令退出码: $ENCRYPT_EXIT_CODE" >> "$LOG_FILE"
    echo "加密结果: $ENCRYPTED_RESULT" >> "$LOG_FILE"
    
    if [ $ENCRYPT_EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓ 文本加密成功${NC}"
        
        # 解密
        echo -e "${GREEN}正在解密文本...${NC}"
        DECRYPTED_RESULT=$(echo "$ENCRYPTED_RESULT" | "$BASE_DIR/text_crypto.sh" decrypt "$TEST_PASSWORD")
        DECRYPT_EXIT_CODE=$?
        
        echo "解密命令退出码: $DECRYPT_EXIT_CODE" >> "$LOG_FILE"
        echo "解密结果: $DECRYPTED_RESULT" >> "$LOG_FILE"
        
        if [ $DECRYPT_EXIT_CODE -eq 0 ]; then
            # 检查解密结果是否与原始文本匹配
            if [ "$DECRYPTED_RESULT" = "$TEST_TEXT" ]; then
                echo -e "${GREEN}✓ 文本解密成功，内容完全匹配${NC}"
                echo "文本解密结果: 成功，内容完全匹配" >> "$LOG_FILE"
                return 0
            else
                echo -e "${RED}✗ 文本解密失败：解密内容与原始文本不匹配${NC}"
                echo "文本解密结果: 失败，内容不匹配" >> "$LOG_FILE"
                return 1
            fi
        else
            echo -e "${RED}✗ 文本解密失败：解密命令执行错误${NC}"
            echo "文本解密结果: 失败，命令执行错误" >> "$LOG_FILE"
            return 1
        fi
    else
        echo -e "${RED}✗ 文本加密失败${NC}"
        echo "文本加密结果: 失败" >> "$LOG_FILE"
        return 1
    fi
}

test_file_encryption() {
    echo -e "\n${YELLOW}2. 测试文件加密解密功能${NC}"
    echo "\n2. 文件加密解密测试" >> "$LOG_FILE"
    
    # 创建测试文件
    TEST_FILE="$DATA_DIR/test_file_$(date +"%Y%m%d_%H%M%S").txt"
    TEST_PASSWORD="FilePassword456"
    ENCRYPTED_FILE="$RESULTS_DIR/test_encrypted.enc"
    DECRYPTED_FILE="$RESULTS_DIR/test_decrypted.txt"
    
    # 生成测试文件内容
    echo "这是一个用于文件加密测试的文本文件。" > "$TEST_FILE"
    echo "包含多行内容和一些特殊字符！@#$%^&*()" >> "$TEST_FILE"
    echo "测试文件加密解密功能。" >> "$TEST_FILE"
    echo "测试大文件处理能力。" >> "$TEST_FILE"
    echo "$(date) - 测试时间戳" >> "$TEST_FILE"
    
    echo "测试文件: $TEST_FILE" >> "$LOG_FILE"
    echo "加密文件: $ENCRYPTED_FILE" >> "$LOG_FILE"
    echo "解密文件: $DECRYPTED_FILE" >> "$LOG_FILE"
    
    # 加密文件
    echo -e "${GREEN}正在加密文件...${NC}"
    "$BASE_DIR/file_crypto.sh" encrypt "$TEST_FILE" "$ENCRYPTED_FILE" "$TEST_PASSWORD"
    ENCRYPT_EXIT_CODE=$?
    
    echo "文件加密命令退出码: $ENCRYPT_EXIT_CODE" >> "$LOG_FILE"
    
    if [ $ENCRYPT_EXIT_CODE -eq 0 ] && [ -f "$ENCRYPTED_FILE" ]; then
        echo -e "${GREEN}✓ 文件加密成功${NC}"
        
        # 解密文件
        echo -e "${GREEN}正在解密文件...${NC}"
        "$BASE_DIR/file_crypto.sh" decrypt "$ENCRYPTED_FILE" "$DECRYPTED_FILE" "$TEST_PASSWORD"
        DECRYPT_EXIT_CODE=$?
        
        echo "文件解密命令退出码: $DECRYPT_EXIT_CODE" >> "$LOG_FILE"
        
        if [ $DECRYPT_EXIT_CODE -eq 0 ] && [ -f "$DECRYPTED_FILE" ]; then
            # 比较文件内容
            DIFF_RESULT=$(diff "$TEST_FILE" "$DECRYPTED_FILE")
            
            if [ -z "$DIFF_RESULT" ]; then
                echo -e "${GREEN}✓ 文件解密成功，内容完全一致${NC}"
                echo "文件解密结果: 成功，内容完全一致" >> "$LOG_FILE"
                return 0
            else
                echo -e "${RED}✗ 文件解密失败：解密内容与原始文件不匹配${NC}"
                echo "文件解密结果: 失败，内容不匹配" >> "$LOG_FILE"
                return 1
            fi
        else
            echo -e "${RED}✗ 文件解密失败：解密命令执行错误或解密文件未生成${NC}"
            echo "文件解密结果: 失败，命令执行错误或文件未生成" >> "$LOG_FILE"
            return 1
        fi
    else
        echo -e "${RED}✗ 文件加密失败：加密命令执行错误或加密文件未生成${NC}"
        echo "文件加密结果: 失败，命令执行错误或文件未生成" >> "$LOG_FILE"
        return 1
    fi
}

test_error_cases() {
    echo -e "\n${YELLOW}3. 测试错误处理情况${NC}"
    echo "\n3. 错误处理测试" >> "$LOG_FILE"
    
    local all_passed=true
    
    # 测试错误密码
    echo -e "${GREEN}测试错误密码解密...${NC}"
    TEST_TEXT="错误密码测试"
    TEST_PASSWORD="CorrectPassword"
    WRONG_PASSWORD="WrongPassword"
    
    ENCRYPTED_RESULT=$(echo "$TEST_TEXT" | "$BASE_DIR/text_crypto.sh" encrypt "$TEST_PASSWORD")
    DECRYPT_RESULT=$(echo "$ENCRYPTED_RESULT" | "$BASE_DIR/text_crypto.sh" decrypt "$WRONG_PASSWORD" 2>&1)
    DECRYPT_EXIT_CODE=$?
    
    echo "错误密码测试退出码: $DECRYPT_EXIT_CODE" >> "$LOG_FILE"
    
    if [ $DECRYPT_EXIT_CODE -ne 0 ] && [[ $DECRYPT_RESULT == *"失败"* ]]; then
        echo -e "${GREEN}✓ 错误密码处理正确${NC}"
        echo "错误密码测试结果: 成功，正确拒绝错误密码" >> "$LOG_FILE"
    else
        echo -e "${RED}✗ 错误密码处理失败：应该拒绝但没有拒绝${NC}"
        echo "错误密码测试结果: 失败，未能正确拒绝错误密码" >> "$LOG_FILE"
        all_passed=false
    fi
    
    # 测试损坏的数据
    echo -e "${GREEN}测试损坏数据解密...${NC}"
    CORRUPTED_DATA="corrupted:data:here"
    DECRYPT_RESULT=$(echo "$CORRUPTED_DATA" | "$BASE_DIR/text_crypto.sh" decrypt "$TEST_PASSWORD" 2>&1)
    DECRYPT_EXIT_CODE=$?
    
    echo "损坏数据测试退出码: $DECRYPT_EXIT_CODE" >> "$LOG_FILE"
    
    if [ $DECRYPT_EXIT_CODE -ne 0 ] && [[ $DECRYPT_RESULT == *"失败"* ]]; then
        echo -e "${GREEN}✓ 损坏数据处理正确${NC}"
        echo "损坏数据测试结果: 成功，正确处理损坏数据" >> "$LOG_FILE"
    else
        echo -e "${RED}✗ 损坏数据处理失败：应该报错但没有报错${NC}"
        echo "损坏数据测试结果: 失败，未能正确处理损坏数据" >> "$LOG_FILE"
        all_passed=false
    fi
    
    if $all_passed; then
        return 0
    else
        return 1
    fi
}

test_text_encryption_interactive() {
    echo -e "\n${YELLOW}4. 测试文本加密解密交互式功能${NC}"
    echo "\n4. 文本加密解密交互式测试" >> "$LOG_FILE"
    
    # 测试文本和密码
    TEST_TEXT="这是一个交互式测试文本，包含中文和特殊字符！@#$%&*()"
    TEST_PASSWORD="InteractivePassword789"
    
    # 交互式加密测试
    echo -e "${GREEN}正在测试交互式文本加密...${NC}"
    
    # 创建临时脚本，使用expect模拟交互式输入
    AUTO_INPUT_SCRIPT="$RESULTS_DIR/auto_input_enc.sh"
    cat > "$AUTO_INPUT_SCRIPT" << EOF
#!/bin/bash
# 先输入文本，再输入密钥
cat << INPUT | "$BASE_DIR/text_crypto.sh" encrypt
$TEST_TEXT
$TEST_PASSWORD
INPUT
EOF
    chmod +x "$AUTO_INPUT_SCRIPT"
    
    ENCRYPTED_RESULT=$("$AUTO_INPUT_SCRIPT")
    ENCRYPT_EXIT_CODE=$?
    
    echo "交互式加密命令退出码: $ENCRYPT_EXIT_CODE" >> "$LOG_FILE"
    echo "交互式加密结果: $ENCRYPTED_RESULT" >> "$LOG_FILE"
    
    if [ $ENCRYPT_EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓ 交互式文本加密成功${NC}"
        
        # 交互式解密测试
        echo -e "${GREEN}正在测试交互式文本解密...${NC}"
        
        AUTO_INPUT_DEC_SCRIPT="$RESULTS_DIR/auto_input_dec.sh"
        cat > "$AUTO_INPUT_DEC_SCRIPT" << EOF
#!/bin/bash
# 先输入密文，再输入密钥
cat << INPUT | "$BASE_DIR/text_crypto.sh" decrypt
$ENCRYPTED_RESULT
$TEST_PASSWORD
INPUT
EOF
        chmod +x "$AUTO_INPUT_DEC_SCRIPT"
        
        DECRYPTED_RESULT=$("$AUTO_INPUT_DEC_SCRIPT")
        DECRYPT_EXIT_CODE=$?
        
        echo "交互式解密命令退出码: $DECRYPT_EXIT_CODE" >> "$LOG_FILE"
        echo "交互式解密结果: $DECRYPTED_RESULT" >> "$LOG_FILE"
        
        if [ $DECRYPT_EXIT_CODE -eq 0 ]; then
            # 检查解密结果是否与原始文本匹配
            if [ "$DECRYPTED_RESULT" = "$TEST_TEXT" ]; then
                echo -e "${GREEN}✓ 交互式文本解密成功，内容完全匹配${NC}"
                echo "交互式文本解密结果: 成功，内容完全匹配" >> "$LOG_FILE"
                # 清理临时文件
                rm -f "$AUTO_INPUT_SCRIPT" "$AUTO_INPUT_DEC_SCRIPT"
                return 0
            else
                echo -e "${RED}✗ 交互式文本解密失败：解密内容与原始文本不匹配${NC}"
                echo "交互式文本解密结果: 失败，内容不匹配" >> "$LOG_FILE"
                rm -f "$AUTO_INPUT_SCRIPT" "$AUTO_INPUT_DEC_SCRIPT"
                return 1
            fi
        else
            echo -e "${RED}✗ 交互式文本解密失败：解密命令执行错误${NC}"
            echo "交互式文本解密结果: 失败，命令执行错误" >> "$LOG_FILE"
            rm -f "$AUTO_INPUT_SCRIPT" "$AUTO_INPUT_DEC_SCRIPT"
            return 1
        fi
    else
        echo -e "${RED}✗ 交互式文本加密失败${NC}"
        echo "交互式文本加密结果: 失败" >> "$LOG_FILE"
        # 清理临时文件
        rm -f "$AUTO_INPUT_SCRIPT"
        return 1
    fi
}

test_file_encryption_interactive() {
    echo -e "\n${YELLOW}5. 测试文件加密解密交互式功能${NC}"
    echo "\n5. 文件加密解密交互式测试" >> "$LOG_FILE"
    
    # 创建测试文件
    TEST_FILE="$DATA_DIR/test_file_interactive_$(date +"%Y%m%d_%H%M%S").txt"
    TEST_PASSWORD="InteractiveFilePassword456"
    ENCRYPTED_FILE="$RESULTS_DIR/test_encrypted_interactive.enc"
    DECRYPTED_FILE="$RESULTS_DIR/test_decrypted_interactive.txt"
    
    # 生成测试文件内容
    echo "这是一个用于交互式文件加密测试的文本文件。" > "$TEST_FILE"
    echo "包含多行内容和一些特殊字符！@#$%&*()" >> "$TEST_FILE"
    echo "测试交互式文件加密解密功能。" >> "$TEST_FILE"
    echo "测试大文件处理能力。" >> "$TEST_FILE"
    echo "$(date) - 测试时间戳" >> "$TEST_FILE"
    
    echo "交互式测试文件: $TEST_FILE" >> "$LOG_FILE"
    echo "交互式加密文件: $ENCRYPTED_FILE" >> "$LOG_FILE"
    echo "交互式解密文件: $DECRYPTED_FILE" >> "$LOG_FILE"
    
    # 交互式加密文件测试
    echo -e "${GREEN}正在测试交互式文件加密...${NC}"
    
    # 创建临时脚本，使用更可靠的管道方式传递密钥
    AUTO_INPUT_ENC_SCRIPT="$RESULTS_DIR/auto_input_enc.sh"
    cat > "$AUTO_INPUT_ENC_SCRIPT" << EOF
#!/bin/bash
# 自动输入密钥的脚本
cat << INPUT | "$BASE_DIR/file_crypto.sh" encrypt "$TEST_FILE" "$ENCRYPTED_FILE"
$TEST_PASSWORD
INPUT
EOF
    chmod +x "$AUTO_INPUT_ENC_SCRIPT"
    
    ENCRYPTED_RESULT=$("$AUTO_INPUT_ENC_SCRIPT")
    ENCRYPT_EXIT_CODE=$?
    
    echo "交互式文件加密命令退出码: $ENCRYPT_EXIT_CODE" >> "$LOG_FILE"
    
    if [ $ENCRYPT_EXIT_CODE -eq 0 ] && [ -f "$ENCRYPTED_FILE" ]; then
        echo -e "${GREEN}✓ 交互式文件加密成功${NC}"
        
        # 交互式解密文件测试
        echo -e "${GREEN}正在测试交互式文件解密...${NC}"
        
        AUTO_INPUT_DEC_SCRIPT="$RESULTS_DIR/auto_input_dec.sh"
        cat > "$AUTO_INPUT_DEC_SCRIPT" << EOF
#!/bin/bash
# 自动输入密钥的脚本
cat << INPUT | "$BASE_DIR/file_crypto.sh" decrypt "$ENCRYPTED_FILE" "$DECRYPTED_FILE"
$TEST_PASSWORD
INPUT
EOF
        chmod +x "$AUTO_INPUT_DEC_SCRIPT"
        
        DECRYPTED_RESULT=$("$AUTO_INPUT_DEC_SCRIPT")
        DECRYPT_EXIT_CODE=$?
        
        echo "交互式文件解密命令退出码: $DECRYPT_EXIT_CODE" >> "$LOG_FILE"
        
        if [ $DECRYPT_EXIT_CODE -eq 0 ] && [ -f "$DECRYPTED_FILE" ]; then
            # 比较文件内容
            DIFF_RESULT=$(diff "$TEST_FILE" "$DECRYPTED_FILE")
            
            if [ -z "$DIFF_RESULT" ]; then
                echo -e "${GREEN}✓ 交互式文件解密成功，内容完全一致${NC}"
                echo "交互式文件解密结果: 成功，内容完全一致" >> "$LOG_FILE"
                # 清理临时文件
                rm -f "$AUTO_INPUT_ENC_SCRIPT" "$AUTO_INPUT_DEC_SCRIPT"
                return 0
            else
                echo -e "${RED}✗ 交互式文件解密失败：解密内容与原始文件不匹配${NC}"
                echo "交互式文件解密结果: 失败，内容不匹配" >> "$LOG_FILE"
                rm -f "$AUTO_INPUT_ENC_SCRIPT" "$AUTO_INPUT_DEC_SCRIPT"
                return 1
            fi
        else
            echo -e "${RED}✗ 交互式文件解密失败：解密命令执行错误或解密文件未生成${NC}"
            echo "交互式文件解密结果: 失败，命令执行错误或文件未生成" >> "$LOG_FILE"
            rm -f "$AUTO_INPUT_ENC_SCRIPT" "$AUTO_INPUT_DEC_SCRIPT"
            return 1
        fi
    else
        echo -e "${RED}✗ 交互式文件加密失败：加密命令执行错误或加密文件未生成${NC}"
        echo "交互式文件加密结果: 失败，命令执行错误或文件未生成" >> "$LOG_FILE"
        rm -f "$AUTO_INPUT_ENC_SCRIPT"
        return 1
    fi
}

# 运行所有测试
echo -e "${YELLOW}\n=========================================${NC}"
echo -e "${YELLOW}开始执行测试套件${NC}"
echo -e "${YELLOW}\n=========================================${NC}"

# 保存测试结果
test_results=()

# 运行文本加密解密测试
test_text_encryption
test_results+=("文本加密解密: $?")

# 运行交互式文本加密解密测试
test_text_encryption_interactive
test_results+=("交互式文本加密解密: $?")

# 运行文件加密解密测试
test_file_encryption
test_results+=("文件加密解密: $?")

# 运行交互式文件加密解密测试
test_file_encryption_interactive
test_results+=("交互式文件加密解密: $?")

# 运行错误处理测试
test_error_cases
test_results+=("错误处理: $?")

# 生成测试报告
echo -e "${YELLOW}\n=========================================${NC}"
echo -e "${YELLOW}测试报告${NC}"
echo -e "${YELLOW}=========================================${NC}"

echo "\n3. 测试结果摘要" >> "$LOG_FILE"

total_tests=${#test_results[@]}
passed_tests=0

for result in "${test_results[@]}"; do
    test_name=$(echo "$result" | cut -d':' -f1)
    test_status=$(echo "$result" | cut -d':' -f2 | tr -d ' ')
    
    if [ "$test_status" -eq 0 ]; then
        echo -e "${GREEN}✓ $test_name: 成功${NC}"
        echo "✓ $test_name: 成功" >> "$LOG_FILE"
        passed_tests=$((passed_tests + 1))
    else
        echo -e "${RED}✗ $test_name: 失败${NC}"
        echo "✗ $test_name: 失败" >> "$LOG_FILE"
    fi
done

echo -e "${YELLOW}\n=========================================${NC}"
echo -e "${YELLOW}测试统计: $passed_tests/$total_tests 测试通过${NC}"
echo -e "${YELLOW}=========================================${NC}"

echo "\n4. 测试统计" >> "$LOG_FILE"
echo "测试总数: $total_tests" >> "$LOG_FILE"
echo "通过测试数: $passed_tests" >> "$LOG_FILE"
echo "通过率: $((passed_tests * 100 / total_tests))%" >> "$LOG_FILE"
echo "测试结束时间: $(date)" >> "$LOG_FILE"

echo -e "\n${GREEN}测试日志已保存至: $LOG_FILE${NC}"

# 设置脚本执行权限
chmod +x "$0"

# 清理测试文件和日志
echo -e "\n${YELLOW}开始清理测试文件和日志...${NC}"

# 安全检查：确保目录存在且是正确的测试目录
if [[ "$DATA_DIR" == *"/tests/data" ]] && [[ -d "$DATA_DIR" ]]; then
    echo -e "${GREEN}清理测试数据目录中的测试文件...${NC}"
    # 清理所有测试产生的文件
    test_files=$(ls -1 "$DATA_DIR"/test_file_* 2>/dev/null)
    if [ -n "$test_files" ]; then
        rm -f "$DATA_DIR"/test_file_*
        echo -e "${GREEN}✓ 已清理测试数据文件${NC}"
    else
        echo -e "${GREEN}✓ 没有需要清理的测试数据文件${NC}"
    fi
else
    echo -e "${RED}✗ 安全检查失败：数据目录路径不正确或不存在${NC}"
fi

if [[ "$RESULTS_DIR" == *"/tests/results" ]] && [[ -d "$RESULTS_DIR" ]]; then
    echo -e "${GREEN}清理结果目录中的测试文件...${NC}"
    # 只清理当前测试产生的特定格式文件
    rm -f "$RESULTS_DIR/test_results.log" 2>/dev/null
    rm -f "$RESULTS_DIR/test_encrypted.enc" 2>/dev/null
    rm -f "$RESULTS_DIR/test_decrypted.txt" 2>/dev/null
    rm -f "$RESULTS_DIR/test_encrypted_interactive.enc" 2>/dev/null
    rm -f "$RESULTS_DIR/test_decrypted_interactive.txt" 2>/dev/null
    rm -f "$RESULTS_DIR/error_test_*.txt" 2>/dev/null
    echo -e "${GREEN}✓ 已清理测试结果文件${NC}"
else
    echo -e "${RED}✗ 安全检查失败：结果目录路径不正确或不存在${NC}"
fi

# 清理临时脚本文件
echo -e "${GREEN}清理临时脚本文件...${NC}"
rm -f "$BASE_DIR/auto_input_enc.sh" "$BASE_DIR/auto_input_dec.sh" 2>/dev/null
echo -e "${GREEN}✓ 已清理临时脚本文件${NC}"

# 返回整体测试结果
if [ $passed_tests -eq $total_tests ]; then
    echo -e "\n${GREEN}🎉 所有测试通过！${NC}"
    exit 0
else
    echo -e "\n${RED}❌ 有测试失败！${NC}"
    exit 1
fi