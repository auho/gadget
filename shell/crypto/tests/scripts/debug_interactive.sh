#!/bin/bash

# 调试交互式输入问题
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# 测试1: 打印环境信息
echo "测试交互式输入调试"
echo "-------------------"
echo "BASE_DIR: $BASE_DIR"

# 测试2: 直接测试交互式输入
AUTO_INPUT_SCRIPT="$BASE_DIR/tests/scripts/test_input.sh"
cat > "$AUTO_INPUT_SCRIPT" << EOF
#!/bin/bash
# 先输入文本，再输入密钥
cat << INPUT | "$BASE_DIR/text_crypto.sh" encrypt
测试文本
TestPassword123
INPUT
EOF

chmod +x "$AUTO_INPUT_SCRIPT"
echo "运行测试脚本..."
$AUTO_INPUT_SCRIPT
EXIT_CODE=$?
echo "退出码: $EXIT_CODE"

# 清理
rm -f "$AUTO_INPUT_SCRIPT"
