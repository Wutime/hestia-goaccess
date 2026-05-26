# hestia-goaccess realtime template fixture
log-file /var/log/%web_system%/domains/%domain%.log
log-format COMBINED
output %home%/%user%/web/%domain%/stats/index.html
real-time-html true
addr 127.0.0.1
port %port%
ws-url /vstats/ws
anonymize-ip true
no-query-string true

