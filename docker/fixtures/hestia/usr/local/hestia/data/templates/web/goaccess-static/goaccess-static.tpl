# hestia-goaccess static template fixture
log-file /var/log/%web_system%/domains/%domain%.log
log-format COMBINED
output %home%/%user%/web/%domain%/stats/index.html
anonymize-ip true
no-query-string true

