# AES-256-CBC 加密工具集

## 项目概述

这是一个基于Bash和OpenSSL实现的AES-256-CBC加密工具集，提供文本和文件的加密解密功能。本工具适用于需要对敏感数据进行安全加密的场景，可用于个人或小型团队的日常数据保护。

## 功能特点

- **文本加密/解密**：支持通过标准输入/输出或交互式输入进行文本加密和解密
- **文件加密/解密**：支持文件的加密和解密操作
- **交互式输入**：支持在命令行未提供明文/密文或密钥时，通过交互式方式输入（先输入文本/密文，再输入密钥）
- **安全的密钥派生**：使用PBKDF2算法从密码生成安全的加密密钥
- **自动生成盐值**：每次加密自动生成随机盐值，提高安全性
- **详细的日志记录**：支持DEBUG级别日志，方便调试
- **错误处理**：完善的错误处理和用户提示

## 系统要求

- **操作系统**：Linux/macOS
- **依赖项**：
  - `openssl` (版本 1.0.2 或更高)
  - `bash` (版本 4.0 或更高)

### 安装依赖

**Ubuntu/Debian**：
```bash
sudo apt-get update
sudo apt-get install openssl bash
```

**CentOS/RHEL**：
```bash
sudo yum install openssl bash
```

**macOS**：
```bash
# 使用Homebrew安装
brew install openssl
# macOS已预装bash，但可能不是最新版本
brew install bash
```

## 安装说明

1. 克隆或下载本仓库到本地
2. 确保所有脚本文件具有执行权限：
   ```bash
   chmod +x *.sh
   ```
3. 验证依赖项安装：
   ```bash
   openssl version
   bash --version
   ```

## 文件结构

- `crypto_lib.sh`：核心加密库，包含所有加密解密的底层函数
- `text_crypto.sh`：文本加密解密工具，用于处理文本数据
- `file_crypto.sh`：文件加密解密工具，用于处理文件
- `README.md`：使用说明文档
- `tests/`：测试相关文件
  - `README.md`：测试文档
  - `scripts/run_tests.sh`：自动化测试脚本，用于验证功能的正确性

## 使用方法

### 文本加密解密

#### 加密文本

**基本用法**：
```bash
# 方法1: 从标准输入加密文本
echo "要加密的文本" | ./text_crypto.sh encrypt 密码

# 方法2: 从文件读取明文并加密
cat plaintext.txt | ./text_crypto.sh encrypt 密码

# 方法3: 交互式输入文本和密钥
./text_crypto.sh encrypt
# 然后按照提示先输入文本，再输入密钥
```

**加密结果格式**：
```
盐值:IV:Base64加密数据
```

#### 解密文本

**基本用法**：
```bash
# 方法1: 解密加密的文本
echo "盐值:IV:Base64加密数据" | ./text_crypto.sh decrypt 密码

# 方法2: 从文件读取密文并解密
cat ciphertext.txt | ./text_crypto.sh decrypt 密码

# 方法3: 交互式输入密文和密钥
./text_crypto.sh decrypt
# 然后按照提示先输入密文，再输入密钥
```

### 文件加密解密

#### 加密文件

**基本用法**：
```bash
# 方法1: 命令行提供密钥
./file_crypto.sh encrypt 源文件 目标文件 密码

# 方法2: 交互式输入密钥
./file_crypto.sh encrypt 源文件 目标文件
# 然后按照提示输入密钥
```

#### 解密文件

**基本用法**：
```bash
# 方法1: 命令行提供密钥
./file_crypto.sh decrypt 源文件 目标文件 密码

# 方法2: 交互式输入密钥
./file_crypto.sh decrypt 源文件 目标文件
# 然后按照提示输入密钥
```

### 调试模式

**启用调试日志**：
```bash
# 设置环境变量启用调试日志
export DEBUG=true
echo "测试文本" | ./text_crypto.sh encrypt 密码
```

## 安全说明

- 密码强度至关重要，请使用强密码
- 加密数据格式中包含盐值和IV，但不包含密码，安全存储密码是用户的责任
- 建议定期更新加密算法和参数以保持最佳安全性
- 本工具仅提供基本的加密功能，高安全性场景请使用专业的加密解决方案

## 示例

### 文本加密解密示例

```bash
# 示例1: 加密文本（标准输入）
$ echo "这是一个测试文本" | ./text_crypto.sh encrypt MySecurePassword
4b706b36365073665835506a55545a56:a7e8f9d0c1b2a3b4c5d6e7f8a9b0c1d2:U2FsdGVkX1+aX93n8Q8KXtD3a1yS7z1qL5mN8kO9pR2wT4eY7vA6b
文本加密成功！

# 示例2: 解密文本（标准输入）
$ echo "4b706b36365073665835506a55545a56:a7e8f9d0c1b2a3b4c5d6e7f8a9b0c1d2:U2FsdGVkX1+aX93n8Q8KXtD3a1yS7z1qL5mN8kO9pR2wT4eY7vA6b" | ./text_crypto.sh decrypt MySecurePassword
这是一个测试文本
文本解密成功！

# 示例3: 交互式加密文本（先输入文本，再输入密钥）
$ ./text_crypto.sh encrypt
请输入要加密的文本: 这是一个交互式加密测试
请输入密钥（至少8个字符）: *******
4b706b36365073665835506a55545a56:a7e8f9d0c1b2a3b4c5d6e7f8a9b0c1d2:U2FsdGVkX1+aX93n8Q8KXtD3a1yS7z1qL5mN8kO9pR2wT4eY7vA6b
文本加密成功！

# 示例4: 交互式解密文本（先输入密文，再输入密钥）
$ ./text_crypto.sh decrypt
请输入要解密的文本（格式: salt:iv:encrypted_data）: 4b706b36365073665835506a55545a56:a7e8f9d0c1b2a3b4c5d6e7f8a9b0c1d2:U2FsdGVkX1+aX93n8Q8KXtD3a1yS7z1qL5mN8kO9pR2wT4eY7vA6b
请输入密钥（至少8个字符）: *******
这是一个交互式加密测试
文本解密成功！
```

### 文件加密解密示例

```bash
# 创建测试文件
$ echo "这是一个测试文件内容" > test_file.txt

# 示例1: 通过命令行提供密钥加密文件
$ ./file_crypto.sh encrypt test_file.txt test_file.enc MySecurePassword
文件加密成功！

# 查看加密后的文件内容（已被加密为二进制数据）
$ ls -la test_file.*
-rw-r--r--  1 user  staff    21  5 20 10:00 test_file.txt
-rw-r--r--  1 user  staff   128  5 20 10:01 test_file.enc

# 示例2: 通过命令行提供密钥解密文件
$ ./file_crypto.sh decrypt test_file.enc test_file_decrypted.txt MySecurePassword
文件解密成功！

# 验证解密后的文件内容
$ cat test_file_decrypted.txt
这是一个测试文件内容

# 示例3: 交互式输入密钥加密文件
$ ./file_crypto.sh encrypt test_file.txt test_file_interactive.enc
请输入密钥（至少8个字符）: *******
文件加密成功！

# 示例4: 交互式输入密钥解密文件
$ ./file_crypto.sh decrypt test_file_interactive.enc test_file_interactive_decrypted.txt
请输入密钥（至少8个字符）: *******
文件解密成功！

# 验证交互式解密后的文件内容
$ cat test_file_interactive_decrypted.txt
这是一个测试文件内容
```

## 故障排除

### 常见错误

1. **"文本解密过程失败，可能是密钥错误或数据损坏"**
   - 确保使用了正确的密码
   - 确保加密数据格式正确（盐值:IV:Base64加密数据）
   - 检查加密数据是否完整，没有被截断或修改

2. **OpenSSL相关错误**
   - 确保OpenSSL版本兼容
   - 检查系统是否正确安装了OpenSSL

## 常见问题解答（FAQ）

### 1. 这个工具使用什么加密算法？
本工具使用AES-256-CBC加密算法，这是一种强加密标准，提供高安全性。

### 2. 如何确保我的密码安全？
工具不会存储您的密码，但密码强度对安全性至关重要。建议：
- 使用至少12位的强密码
- 包含大小写字母、数字和特殊字符
- 不要重复使用密码

### 3. 加密数据的格式是什么？
加密数据采用以下格式：`盐值:IV:Base64加密数据`，其中：
- 盐值：随机生成的值，用于密钥派生
- IV：初始化向量，确保相同数据加密结果不同
- Base64加密数据：使用AES-256-CBC加密后的数据（Base64编码）

### 4. 这个工具可以加密大型文件吗？
是的，但对于特别大的文件（如超过几GB），可能会消耗较多系统资源，建议分批处理。

### 5. 如何确保加密的安全性？
- 使用强密码
- 安全存储加密后的文件
- 定期更新工具（如果有新版本）
- 对于高安全性场景，考虑使用专业的加密解决方案

## 测试

本项目包含自动化测试脚本，可以验证所有功能的正确性。

### 运行测试

```bash
# 执行测试脚本
./tests/scripts/run_tests.sh
```

测试脚本会验证以下功能：
- 文本加密解密功能
- 文件加密解密功能
- 错误处理机制（错误密码和损坏数据）

测试结果会输出到控制台，并保存到`tests/results/test_results.log`文件中。

### 测试覆盖范围

- ✓ 文本加密功能
- ✓ 文本解密功能
- ✓ 文件加密功能
- ✓ 文件解密功能
- ✓ 错误密码处理
- ✓ 损坏数据处理
