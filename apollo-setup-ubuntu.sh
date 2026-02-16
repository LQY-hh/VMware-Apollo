#!/bin/bash
# ==============================================================================
# Apollo 包管理安装全流程脚本（新手专用）
# 适用系统：Ubuntu 18.04+（官方指定） | 适配版本：Apollo 9.0+ 包管理安装
# 前置要求：
# 1. 物理机（虚拟机无法安装NVIDIA驱动，WSL需单独适配）
# 2. 外网通畅（建议配置国内源/代理）
# 3. 磁盘空间≥50GB（含镜像、工程、数据包）
# 4. 全程使用sudo权限执行，避免权限不足
# 执行方式：chmod +x apollo_full_install.sh && sudo ./apollo_full_install.sh
# ==============================================================================

# ============================ 一、基础软件安装 ============================
# 1.1 系统更新（解决后续安装包找不到的问题，网络异常可换国内源）
echo "===== 开始系统更新 ====="
sudo apt-get update
sudo apt-get upgrade -y
# 易出错点：
# - 更新卡住/失败：检查网络连接，或替换Ubuntu国内源（阿里云/清华源）
# - 提示「锁被占用」：执行 sudo rm /var/lib/dpkg/lock-frontend 后重试

# 1.2 安装Docker Engine（Apollo依赖19.03+）
echo -e "\n===== 开始安装Docker Engine ====="
# 方式1：Apollo官方脚本（推荐新手，可能需多次运行）
wget http://apollo-pkg-beta.bj.bcebos.com/docker_install.sh
chmod +x docker_install.sh
bash docker_install.sh
# 方式2：手动安装（脚本失败时备用）
# sudo apt-get remove -y docker docker-engine docker.io containerd runc
# sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg
# sudo install -m 0755 -d /etc/apt/keyrings
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# sudo chmod a+r /etc/apt/keyrings/docker.gpg
# echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
docker --version  # 验证安装
# 配置Docker权限（免sudo使用）
sudo usermod -aG docker $USER
sudo systemctl restart docker  # 重启生效
# 易出错点：
# - 脚本下载失败：替换地址为 https://apollo-pkg-beta.cdn.bcebos.com/docker_install.sh
# - Docker启动失败：执行 journalctl -u docker 查看日志，常见原因是Docker未启动/GPU驱动不兼容

# ============================ 二、GPU支持安装（可选，感知模块必需） ============================
echo -e "\n===== 开始安装GPU支持（可选） ====="
# 2.1 安装NVIDIA显卡驱动（物理机专属，跳过条件：nvidia-smi能正常输出显卡信息）
# 下载推荐驱动（以470.63.01为例，适配10/20/30系显卡）
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/470.63.01/NVIDIA-Linux-x86_64-470.63.01.run
sudo chmod 777 NVIDIA-Linux-x86_64-470.63.01.run
sudo service lightdm stop  # 关闭图形界面避免冲突
sudo ./NVIDIA-Linux-x86_64-470.63.01.run  # 按提示选Accept/Yes
nvidia-smi  # 验证安装（输出显卡信息则成功）
# 易出错点：
# - 提示X server运行中：执行 sudo init 3 进入命令行模式重试
# - 驱动不兼容：卸载旧驱动 sudo apt-get purge nvidia*，重新下载对应版本
# - 虚拟机/WSL报错：此类环境无法装物理机驱动，直接跳过GPU步骤

# 2.2 安装NVIDIA Container Toolkit（容器内用GPU）
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get -y update && sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker
docker run --rm --gpus all nvidia/cuda:11.4.0-base nvidia-smi  # 验证
# 易出错点：
# - apt-key add失败：安装 sudo apt-get install -y gnupg2 后重试
# - 容器内识别不到GPU：检查Docker版本≥19.03，驱动与CUDA版本匹配

# ============================ 三、Apollo环境管理工具（aem）安装 ============================
echo -e "\n===== 开始安装Apollo环境管理工具（aem） ====="
# 安装依赖
sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg

# 添加Apollo软件源（删除旧版本源避免冲突）
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://apollo-pkg-beta.cdn.bcebos.com/neo/beta/key/deb.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/apolloauto.gpg
sudo chmod a+r /etc/apt/keyrings/apolloauto.gpg
echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/apolloauto.gpg] https://apollo-pkg-beta.cdn.bcebos.com/apollo/core $(. /etc/os-release && echo "$VERSION_CODENAME") main" | sudo tee /etc/apt/sources.list.d/apolloauto.list
sudo apt-get update

# 安装/重装aem工具
sudo apt install -y apollo-neo-env-manager-dev --reinstall
aem -h  # 验证（输出帮助信息则成功）
# 易出错点：
# - 旧源冲突：删除/etc/apt/sources.list中deb https://apollo-pkg-beta.cdn.bcebos.com/neo/beta bionic main
# - 命令未找到：重启终端或执行 source /etc/profile

# ============================ 四、示例工程安装与验证 ============================
echo -e "\n===== 开始安装示例工程 ====="
# 4.1 克隆工程（以application-core为例，国内镜像：https://gitee.com/ApolloAuto/application-core.git）
git clone https://github.com/ApolloAuto/application-core.git application-core
cd application-core
sudo chmod -R 777 .  # 避免权限问题

# 4.2 配置并启动容器
bash setup.sh  # 环境初始化（自动识别x86_64/aarch64架构）
aem start  # 启动容器（首次拉取镜像耗时10-30分钟）

# 4.3 进入容器并安装依赖
aem enter -c "buildtool build -p core"  # 进入容器并安装依赖
# 易出错点：容器内执行失败则先执行 source /apollo/scripts/apollo_base.sh

# 4.4 配置车型与下载资源
aem profile use sample  # 启用官方示例配置

# 下载数据包（国内镜像：https://apollo-system.bj.bcebos.com/dataset/6.0_edu/demo_3.5.record）
wget https://apollo-system.cdn.bcebos.com/dataset/6.0_edu/demo_3.5.record -P $HOME/.apollo/resources/records/

# 下载高精地图
aem enter -c "buildtool map get sunnyvale"
aem enter -c "buildtool map list"  # 查看可用地图

# 4.5 启动Dreamview+并播放数据包
aem bootstrap start --plus  # 启动Dreamview+服务
# 浏览器操作指引：
# 1. 访问localhost:8888 → 选择Default Mode → 勾选用户协议 → Enter this Mode
# 2. Operations选Record → Records选demo_3.5.record → HDMap选Sunnyvale Big Loop
# 3. 点击底部播放按钮，在Vehicle Visualization查看画面
# 命令行播放（备用，容器内执行）：
# aem enter -c "cyber_recorder play -f ~/.apollo/resources/records/demo_3.5.record -l"  # -l循环播放
# 易出错点：
# - 8888端口被占：sudo lsof -i:8888 找到进程并kill
# - 播放无画面：检查地图/数据包下载完成，车型配置启用

# 4.6 工程目录结构说明
# application-core
# ├── .aem/envroot          # 容器挂载目录（apollo→/apollo，opt→/opt）
# ├── core/cyberfile.xml    # 依赖包描述文件
# ├── data                  # 数据目录（地图/日志/标定数据）
# ├── profiles/sample       # 官方示例车型配置
# └── .workspace.json       # Apollo版本配置

# ============================ 五、工程删除（可选） ============================
# echo -e "\n===== 开始删除示例工程（可选） ====="
# cd application-core
# aem remove  # 删除容器
# cd ..
# rm -rf application-core  # 删除工程目录

# ============================ 六、常见问题汇总 ============================
# | 问题现象                  | 解决方法                                                                 |
# |---------------------------|--------------------------------------------------------------------------|
# | aem命令未找到             | 重启终端 / 重新安装aem / source /etc/profile                             |
# | 容器内识别不到GPU         | 检查NVIDIA驱动/Docker版本/nvidia-docker2安装状态                         |
# | 数据包/地图下载失败       | 替换域名cdn.bcebos.com为bj.bcebos.com，或配置网络代理                     |
# | buildtool依赖安装超时     | 容器内执行export http_proxy=代理地址                                     |
# | Docker拉取镜像失败        | 配置Docker国内镜像加速（阿里云/百度源）                                   |
# | 8888端口被占用            | sudo lsof -i:8888 → kill 进程ID                                          |

# ============================ 七、后续学习 ============================
# 1. 规划实践：参考Apollo官方「Apollo规划实践」文档
# 2. 感知实践：参考Apollo官方「Apollo感知实践」文档
# 3. 问题反馈：前往Apollo开发者社区提交安装/使用问题

# ============================ 安装完成 ============================
echo -e "\n===== Apollo安装完成 =====\n"
echo "核心总结："
echo "1. 核心流程：系统更新→Docker安装→GPU适配（可选）→aem安装→工程部署→数据包验证"
echo "2. 关键避坑：物理机才能装GPU驱动、网络问题优先换国内源/代理、权限问题用sudo/777解决"
echo "3. 备用方案：每个核心步骤均提供双方案，避免单一方式失败导致安装中断"
echo -e "\n使用指引："
echo "1. 进入容器：cd application-core && aem enter"
echo "2. 启动Dreamview+：aem bootstrap start --plus"
echo "3. 访问监控页面：localhost:8888"