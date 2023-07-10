from os import getAppFilename, getAppDir, relativePath, sleep, commandLineParams, normalizeExe, getLastModificationTime
from sequtils import mapIt
from std/osproc import startProcess, running, kill, close, peekExitCode, poUsePath, poEvalCommand, poParentStreams, poStdErrToStdOut
from std/strutils import split, parseFloat, toLowerAscii
from std/terminal import eraseScreen, setCursorPos, hideCursor, showCursor
from std/strformat import `&`
from std/times import Time, epochTime, now, format
from std/parseopt import initOptParser, next
from sugar import dup


type Arguments = object
  command:string # the command to run when files changed
  filenames:seq[string] # the files to watch for changes
  echoCommand:bool # whether to echo the user command every time it's invoked
  timeout:float # how long to wait until considering the user command to be hung (default 3)
  help:bool # whether to show the help message


proc run(args: Arguments) =
  echo now().format("hh:mm:ss")
  let process = startProcess(command=args.command, options={poUsePath, poEvalCommand, poParentStreams, poStdErrToStdOut})

  if args.echoCommand:
    echo args.command
  let timeStart = epochTime()
  var timeMark = timeStart
  var ts = newStringOfCap(128)
  while process.running:
    sleep 500
    if epochTime() - timeStart > args.timeout:
      echo "\nError: process timeout (-t to change limit)"
      stdout.showCursor
      kill process
      break
  let errcode = process.peekExitCode
  if errcode notin [-1,0]:
    echo &"Error:\n{args.command}\nexit code: {errcode}\n"
  close process


proc onControlC {.noconv.} =
  stdout.showCursor
  quit(0)


proc getCommandLineArguments: Arguments =
  var p = initOptParser commandLineParams()
  var args = Arguments(echoCommand: false, timeout: 3.0)
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption: # ex: -o --option
      if p.val == "":
        case p.key.toLowerAscii:
          of "e","echo":
            args.echoCommand = true
          of "h","help":
            args.help = true
          else:
            echo &"Error: unknown flag '{p.key}'"
            echo """(Maybe use "--key:value" or "--key=value"?)"""
            quit(1)
      else: # ex: -o=1 --option=1 --option:1
        case p.key.toLowerAscii:
          of "t","timeout":
            try:
              args.timeout = p.val.parseFloat
            except ValueError:
              echo &"Error: bad number '{p.val}'"
              quit(1)
          else:
            echo &"Error: unknown option '{p.key}'"
            quit(1)
    of cmdArgument: # ex: filename.txt
      # capture first argument as command string
      # all the others assume as filenames / targets to watch
      if args.command.len == 0:
        args.command = p.key
      else:
        args.filenames.add p.key
  return args


proc showHelp =
  let thisfile = relativePath(getAppFilename(),getAppDir()) . dup(normalizeExe)
  echo &"""

On Change Do

Usage: {thisfile} [options] "<command>" <file(s)>...

When changes in files are detected, the command is run.

  command           command to run when files changed
  files(s)...       file(s) to watch for changes

Options:
  -t,--timeout      timeout allowance for command (s)
  -e,--echo         show the command on every invokation
"""


proc main =
  let args = getCommandLineArguments()

  if args.help:
    showHelp()
    quit(1)
  elif args.command.len == 0:
    echo "No command specified"
    quit(1)
  elif args.filenames.len == 0:
    echo "No files specified"
    quit(1)

  stdout.eraseScreen
  setCursorPos(0,0)
  stdout.flushFile

  # keep all up-to-date file timestamps here
  var modTimes = newSeq[Time](args.filenames.len)
  # set up the control hook and hide the cursor
  # at the last possible moment before necessary
  setControlCHook onControlC
  stdout.hideCursor
  # get initial modTimes
  modTimes = args.filenames.mapIt(getLastModificationTime(it))
  # watcher loop
  while true:
    sleep 500
    for file_i,filename in args.filenames:
      if modTimes[file_i] != getLastModificationTime(filename):
        modTimes[file_i] = getLastModificationTime(filename)
        stdout.eraseScreen
        setCursorPos(0,0)
        stdout.flushFile
        run args
  stdout.showCursor

when isMainModule:
  main()
