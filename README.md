# Sensu plugin for monitoring mount points

A sensu plugin to monitor whether entries listed in /etc/fstab are mounted and the other way around, as in currently mounted volumes have an entry in /etc/fstab.

The plugin generates multiple OK/WARN/CRIT/UNKNOWN events via the sensu client socket (https://sensuapp.org/docs/latest/clients#client-socket-input)
so that you do not miss state changes when monitoring multiple mountpoints.

## Usage

The plugin accepts the following command line options:

```
Usage: check-fsmounts.rb (options)
        --fstype <TYPE>              Comma separated list of file system type(s) (default: all)
        --ignore-fstype <TYPE>       Comma separated list of file system type(s) to ignore
        --ignore-mount <MOUNTPOINT>  Comma separated list of mount point(s) to ignore
        --ignore-mount-regex <MOUNTPOINT>
                                     Comma separated list of mount point(s) to ignore (regex)
        --handlers <HANDLERS>        Comma separated list of handlers
        --mount <MOUNTPOINT>         Comma separated list of mount point(s) (default: all)
        --mount-regex <MOUNTPOINT>   Comma separated list of mount point(s) (regex)
    -w, --warn                       Warn instead of throwing a critical failure
```

Use the --handlers command line option to specify which handlers you want to use for the generated events.

## Author
Matteo Cerutti - <matteo.cerutti@hotmail.co.uk>
