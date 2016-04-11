# create log-courier group
if ! getent group log-courier >/dev/null; then
  groupadd -r log-courier
fi

# create log-courier user
if ! getent passwd log-courier >/dev/null; then
  useradd -r -g log-courier -d /opt/log-courier \
    -s /sbin/nologin -c "log-courier" log-courier
fi
