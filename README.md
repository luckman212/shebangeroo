<img src="./icon" width="80" />

# shebangeroo

Recurses over a directory looking for scripts, and tests the ones it finds to make sure they have valid interpreters.

At the end of the run, a logfile will be opened displaying any errors found.

Use `-h` or `--help` for help.

You can specify some additional args to control the behavior, such as limiting the search scope to only shebangs containing a specific regex or string.

```
usage: shebangaroo.sh <path> [regex-search] [max_size]
- use . or leave blank to default to current dir
- example of regex search could be: `python`
- max_size will default to 128k unless spefified
```
