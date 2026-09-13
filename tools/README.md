# tools

Three helpers. Only the first is part of KinFert's verification; the other two maintain the
documents and are needed by nobody building or running the program.

## compareruns.lpr

A Free Pascal console program that compares two results folders cell by cell, or checks
the column counts of one of them against its header rows. It is the out-of-process half
of verification: `Verification.pas` decides what can be checked inside a single run, and
this decides what needs two runs, or a run against a folder kept from an earlier one.

Build it once:

```
cd tools
fpc -O2 compareruns.lpr
```

Then:

```
compareruns A B                 every file, cell by cell
compareruns A B -tol 1e-9       numbers within that relative distance count as equal
compareruns A B -only fec       only files whose name contains fec
compareruns A B -summary        one line per file
compareruns A B -max 5          at most five differences listed per file
compareruns A -headers          column counts against the header row
```

The exit code is 0 when the two folders agree and 1 when they do not, so it can be used
from a script. A file present in one folder only counts as a difference.

## check-line-numbers.py

Re-derives the line numbers quoted in `docs/KinFert-TODO.md` from the working tree, by
searching for a fixed text in each file rather than trusting a number. Run it from the
repository root after any edit. It is a documentation tool and touches no source.

## strip-claude-marks.py

Removes the review markers that Claude leaves around the regions it changes:

```
// >>> Claude 2026-09-02 start
// <<< Claude 2026-09-02 end
```

Run it once a set of changes has been read and accepted. `--list` shows what is marked
without changing anything.

Both Python scripts need only a Python 3 interpreter and are unrelated to the program.
