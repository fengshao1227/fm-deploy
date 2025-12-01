#!/bin/bash
# 在远程服务器上执行此脚本获取私钥

echo "=== 查找私钥文件 ==="
ls -la ~/.ssh/

echo ""
echo "=== 常见的私钥文件 ==="
for key in id_rsa id_ed25519 fm_deploy_key; do
    if [ -f ~/.ssh/$key ]; then
        echo "找到私钥: ~/.ssh/$key"
        echo "内容预览:"
        head -n 2 ~/.ssh/$key
        echo "..."
        echo ""
    fi
done

echo "=== 请选择一个私钥文件查看完整内容 ==="
echo "例如: cat ~/.ssh/id_rsa"
