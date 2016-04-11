/sbin/chkconfig --add log-courier

chown -R log-courier:log-courier /opt/log-courier
chown log-courier /var/log/log-courier
chown log-courier:log-courier /var/lib/log-courier

echo "Logs for log-courier will be in /var/log/log-courier/"
