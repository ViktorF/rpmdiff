# rpmdiff
rpmdiff is a simple script to find and merge new config files in an RPM based Linux system.

*Note*: You need vim installed for merging with vim -d

## Usage:
```
rpmdiff.sh [-l | -f | -p] [--nocolor]
```
### Search Options:     select one (default: --find)
- `-l/--locate` scan using locate
- `-f/--find` scan using find

### General Options:
- `-o/--output` print files instead of merging them
- `--nocolor` remove colors from output

### Environment Variables:
- `DIFFPROG` override the merge program: (default: 'vim -d')
- `DIFFSEARCHPATH` override the search path. (only when using find) (default: /etc)

#### Examples:
```DIFFPROG=meld DIFFSEARCHPATH="/boot /etc /usr" rpmdiff```

```rpmdiff --output --locate```
