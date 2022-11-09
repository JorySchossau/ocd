# ocd
On Change Do: file watcher and single task runner (simple entr replacement)

```
On Change Do

Usage: ./ocd [options] "<command>" <file(s)>...

When changes in files are detected, the command is run.

  command           command to run when files changed
  files(s)...       file(s) to watch for changes

Options:
  -t,--timeout      timeout allowance for command (s)
  -e,--echo         show the command on every invokation

```
