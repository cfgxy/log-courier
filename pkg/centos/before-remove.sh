if [ $1 -eq 0 ]; then
  /sbin/service log-courier stop >/dev/null 2>&1 || true
  /sbin/chkconfig --del log-courier
  if getent passwd log-courier >/dev/null ; then
    userdel log-courier
  fi

  if getent group log-courier > /dev/null ; then
    groupdel log-courier
  fi
fi
