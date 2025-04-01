#!/bin/bash
# shellcheck disable=SC1091
apt-get install -y bsdmainutils
. script/common.sh
. script/clashctl.sh
echo "install begin"
_valid_env
_get_os

[ -d "$CLASH_BASE_DIR" ] && _error_quit "已安装，如需重新安装请先执行卸载脚本"

# shellcheck disable=SC2086
gzip -dc $ZIP_KERNEL >"${TEMP_BIN}/clash" && chmod +x "${TEMP_BIN}/clash"
# shellcheck disable=SC2086
tar -xf $ZIP_CONVERT -C "$TEMP_BIN"
_valid_config "$TEMP_CONFIG" || {
    read -r -p '😼 输入订阅链接：' url
    _download_config "$url" "$TEMP_CONFIG" || _error_quit "下载失败: 请自行粘贴配置内容到 ${TEMP_CONFIG} 后再执行安装脚本"
    _valid_config "$TEMP_CONFIG" || {
        _failcat "配置无效：尝试进行本地订阅转换..."
        _download_convert_config "$TEMP_CONFIG"
        _valid_config "$TEMP_CONFIG" || _error_quit '配置无效：请检查配置内容'
    }
}
echo '✅ 配置可用'
mkdir -p "$CLASH_BASE_DIR"
echo "$url" >"$CLASH_CONFIG_URL"
/bin/cp -rf script "$CLASH_BASE_DIR"
/bin/ls resource | grep -Ev 'zip|png' | xargs -I {} /bin/cp -rf "resource/{}" "$CLASH_BASE_DIR"
tar -xf "$ZIP_UI" -C "$CLASH_BASE_DIR"
# shellcheck disable=SC2086
tar -xf $ZIP_YQ -C "${TEMP_BIN}" && install -m +x ${TEMP_BIN}/yq_* "$BIN_YQ"

_merge_config_restart

cat <<EOF >/etc/init.d/clash
#!/bin/bash
### BEGIN INIT INFO
# Provides:          clash
# Required-Start:    \$network \$remote_fs \$syslog
# Required-Stop:     \$network \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Clash Daemon
# Description:       Clash 守护进程, Go 语言实现的基于规则的代理.
### END INIT INFO

DAEMON="${BIN_CLASH}"
DAEMON_OPTS="-d ${CLASH_BASE_DIR} -f ${CLASH_CONFIG_RUNTIME}"
NAME="clash"
DESC="Clash Daemon"
PIDFILE="/var/run/\$NAME.pid"

case "\$1" in
    start)
        echo "Starting \$DESC"
        start-stop-daemon --start --background --make-pidfile --pidfile \$PIDFILE --exec \$DAEMON -- \$DAEMON_OPTS
        ;;
    stop)
        echo "Stopping \$DESC"
        start-stop-daemon --stop --pidfile \$PIDFILE --exec \$DAEMON
        rm -f \$PIDFILE
        ;;
    restart)
        \$0 stop
        sleep 1
        \$0 start
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart}"
        exit 1
        ;;
esac
exit 0
EOF

chmod +x /etc/init.d/clash

echo "source $CLASH_BASE_DIR/script/common.sh && source $CLASH_BASE_DIR/script/clashctl.sh" >>"$BASHRC"

# 添加开机自启
update-rc.d clash defaults >&/dev/null && _okcat "已设置开机自启" || _failcat "设置自启失败"

clashon && clashui
clash
