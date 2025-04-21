settings {
    logfile = "/var/log/lsyncd.log",
    statusFile = "/var/log/lsyncd-status.log"
}

sync {
    default.rsync,
    source = "/data",
    target = "lab2:/backup",
    rsync = {
        archive = true,
        compress = true,
        password_file = "/etc/lsyncd/rsync-pass",
        _extra = {"--no-owner", "--no-group"}
    }
}
