重启B209电脑后如何继续 Robot 项目

### 1. 打开 Ubuntu 终端

进入 Ubuntu 桌面，按 `Ctrl + Alt + T` 打开终端。

不需要重新安装 ROS、Gazebo 或重新下载 TurtleBot3 源码。

### 2. 进入独立的 Robot 环境

完整复制并执行下面这一组命令：

```bash
env -i \
  HOME="$HOME" USER="$USER" TERM="${TERM:-xterm-256color}" \
  LANG=C.UTF-8 PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  DISPLAY="${DISPLAY:-}" XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}" \
  WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
  DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
  /bin/bash --noprofile --norc
```

提示符变成 `bash-5.2$` 等形式属于正常现象。

这会创建独立的临时终端环境，避开 ESP32 工具路径，并保留图形显示所需的环境信息。项目文件和已安装的软件不会被删除。

### 3. 加载 ROS 和 TurtleBot3

在上一步进入的环境中，继续执行：

```bash
source /opt/ros/jazzy/setup.bash
source ~/turtlebot3_ws/install/local_setup.bash
export ROS_DOMAIN_ID=30
cd ~/turtlebot3_ws
```

完成后，可以继续执行机器人项目的命令。

### 4. 检查环境

```bash
echo $ROS_DISTRO
echo $ROS_DOMAIN_ID
ros2 pkg list | grep turtlebot3
```

预期结果：

- ROS 版本显示 `jazzy`。
- ROS_DOMAIN_ID 显示 `30`。
- 能列出多个 `turtlebot3_...` 软件包。

### 注意事项

- 每个新开的 Robot 终端，都执行第 2、3 步。
- Robot 终端中不要加载 ESP32 的 `export.sh`。
- 暂时不要执行 `source ~/.bashrc`，以免再次加载其中的 ESP32 环境配置。
- ESP32 项目使用另一个终端，按原来的方式启动。
- 重启后不需要重新编译；修改了需要编译的代码时，再执行：

  ```bash
  cd ~/turtlebot3_ws
  colcon build --symlink-install
  source ~/turtlebot3_ws/install/local_setup.bash
  ```

- `--cmake-clean-cache` 用于清理旧配置，不需要每次编译都添加。
- 工作结束后可以关闭终端；源码、编译结果和已保存的文件会保留。
