# socat-proxy

install systemd unit file<br>
```cp socat@.service /etc/systemd/system/socat@.service```

add config with<br>
```add_config.sh --source SOURCE --target TARGET --port PORT --protocol PROTOCOL --ipversion IPVERSION```

remove all config for source with<br>
```rm_config.sh --source SOURCE --ipversion IPVERSION```

If you place the scripts anywhere but /opt/socat-proxy you will have to manually update the systemd unit file before installing
