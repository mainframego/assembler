# assembler

Assembler (HLASM) for IBM z/OS Primer.

A hands-on course on IBM High Level Assembler (HLASM) for z/OS. Each example
comes with fully commented source code, the JCL to assemble, link-edit and run
it, and the job output from a real execution so you can compare your results.

## Repository layout

```
assembler/
├── README.md
├── LICENSE
└── COPYFB/                     Example 1 - copy a FB/80 sequential data set
    ├── COPYFB.asm              HLASM source (commented line by line)
    ├── COPYFBJ.jcl             JCL: allocate test data, assemble, link-edit, run
    └── JOB08172/               Output of a successful run (RC=0000)
        ├── JES2/               JESMSGLG, JESJCL, JESYSMSG
        ├── ASM/SYSPRINT.txt    Assembler listing (ASMA90)
        ├── LKED/SYSPRINT.txt   Binder listing (IEWL)
        └── STEP3/SYSPRINT.txt  IEBGENER output (test data load)
```

## Examples

| # | Program | Topic |
|---|---------|-------|
| 1 | [COPYFB](COPYFB/) | QSAM sequential copy of a `RECFM=FB, LRECL=80` data set |

---

## Example 1 - COPYFB

### What it does

`COPYFB` sequentially reads every record of the data set allocated to DDNAME
`INFILE` (`RECFM=FB, LRECL=80`) and writes it to the data set allocated to
DDNAME `OUTFILE`, which uses the same DCB attributes as the input. At the end
it issues a `WTO` with the number of records copied, which appears in the job
log:

```
+COPYFB - RECORDS COPIED: 000000002
```

### Concepts covered

- **Standard linkage conventions**: saving the caller's registers (`STM`),
  establishing a base register (`USING`), chaining save areas and restoring
  registers on exit.
- **QSAM in move mode**: the `DCB`, `OPEN`, `GET` (`MACRF=GM`), `PUT`
  (`MACRF=PM`) and `CLOSE` macros.
- **End-of-file handling** with the `EODAD` parameter of the DCB.
- **Checking OPEN success** by testing bit `DCBOFOPN` of `DCBOFLGS`, mapped
  by the `IHADCB` DSECT generated with the `DCBD` macro.
- **Number formatting**: `CVD` + `UNPK` + `OI` to turn a binary counter into
  printable zoned decimal.
- **WTO in execute form** (`MF=E`) with a manually built parameter list.
- **Return codes** in R15 and **AMODE/RMODE** attributes.

### Program summary

| Item | Value |
|------|-------|
| Language | HLASM (High Level Assembler for z/OS) |
| Access method | QSAM, move mode (GM/PM) |
| Input DD | `INFILE` - `DSORG=PS, RECFM=FB, LRECL=80` |
| Output DD | `OUTFILE` - same DCB as input, `BLKSIZE` from JCL or system-determined |
| Return codes | `00` normal completion / `16` OPEN failed for INFILE or OUTFILE |
| Attributes | `AMODE 31`, `RMODE 24` (QSAM DCBs must reside below the 16MB line), not reentrant |
| Load module size | 270 bytes (`X'10E'`) |

Registers used:

| Register | Purpose |
|----------|---------|
| R2 | Pointer to the DCB (OPEN check) |
| R5 | Counter of records copied (kept in R5 because `GET`/`PUT` change R0, R1, R14, R15) |
| R11 | Work register for save area chaining |
| R12 | Program base register |
| R13 | Address of this program's save area |
| R14 | Return address to the caller |
| R15 | Entry point address / return code |

### Program flow

1. **Entry linkage** - save the caller's registers, set R12 as base, chain the save areas.
2. **Initialize** the record counter (`SR R5,R5`).
3. **OPEN** `INFILE` for input and `OUTFILE` for output.
4. **Verify** that both DCBs are open; if not, go to `OPENERR`.
5. **Main loop** (`READLOOP`) - `GET` a record into `RECORD`, add 1 to R5, `PUT` it to `OUTFILE`, repeat.
6. **End of file** (`EOFRTN`, reached through `EODAD`) - `CLOSE` both files, format the counter, issue the `WTO`, set RC=0.
7. **Open error** (`OPENERR`) - `CLOSE` whatever is open, issue an error `WTO`, set RC=16.
8. **Exit linkage** (`EXITPGM`) - restore the caller's registers and return with the RC in R15.

### How to assemble, link-edit and run

The job [`COPYFB/COPYFBJ.jcl`](COPYFB/COPYFBJ.jcl) does everything in one
submission.

#### Prerequisites

| Data set | Attributes | Contents |
|----------|------------|----------|
| `&HLQ..ASM` | PDS, `RECFM=FB, LRECL=80` | member `COPYFB` with the source from `COPYFB.asm` |
| `&HLQ..LOAD` | PDS/PDSE, `RECFM=U` | load library that will receive the load module |

#### Customize the JCL

- Change `// SET HLQ=USERID` to your own data set prefix.
- Adjust the JOB card (accounting info, `CLASS`, `MSGCLASS`) for your site.

#### Job steps

| Step | Program | Function |
|------|---------|----------|
| `STEP1` | `IEFBR14` | Delete `&HLQ..DATA.INPUT` and `&HLQ..DATA.OUTPUT` from a previous run (`DISP=(MOD,DELETE,DELETE)` does not fail if they do not exist) |
| `STEP2` | `IEFBR14` | Allocate the input data set `&HLQ..DATA.INPUT` (`RECFM=FB, LRECL=80, BLKSIZE=0`) |
| `STEP3` | `IEBGENER` | Load two test records into the input data set |
| `ASM` | `ASMA90` | Assemble the source with `PARM='OBJECT,NODECK,XREF(SHORT)'`. `SYSLIB` = `SYS1.MACLIB` + `SYS1.MODGEN`; object module goes to the temporary data set `&&OBJ` |
| `LKED` | `IEWL` | Link-edit (Binder) with `PARM='LIST,MAP,XREF'`, creating `&HLQ..LOAD(COPYFB)`. Runs only if `ASM` RC <= 4 |
| `STEP6` | `COPYFB` | Run the program with `STEPLIB=&HLQ..LOAD`, `INFILE=&HLQ..DATA.INPUT`, creating `OUTFILE=&HLQ..DATA.OUTPUT`. Runs only if `ASM` and `LKED` RC <= 4 |

Test data loaded by `STEP3`:

```
LINE01 WORD11 WORD12
LINE02 WORD21 WORD22
```

#### Submit

From ISPF, edit the JCL member and type `SUBMIT` on the command line, or from
TSO:

```
SUBMIT 'USERID.JCL(COPYFBJ)'
```

### Expected results

The folder [`COPYFB/JOB08172`](COPYFB/JOB08172/) has the output of a
successful run. Summary from `JESMSGLG`:

```
-STEPNAME PROCSTEP    RC
-STEP1                00
-STEP2                00
-STEP3                00
-ASM                  00
-LKED                 00
+COPYFB - RECORDS COPIED: 000000002
-STEP6                00
$HASP395 COPYFBJ  ENDED - RC=0000
```

- **Assembly** (`ASM/SYSPRINT.txt`): `Return Code 000`, no warning or error messages.
- **Link-edit** (`LKED/SYSPRINT.txt`): module saved with `AMODE 31`, `RMODE 24`,
  `IEW2008I ... PROCESSING COMPLETED. RETURN CODE = 0`.
- **Execution**: `&HLQ..DATA.OUTPUT` contains the same 2 records as the input.
  With `BLKSIZE=0` the system calculates the optimal block size (27920 on a
  3390 disk).

### Things to try

- Change the test data in `STEP3` to load more records and check the counter in the `WTO`.
- Remove the `INFILE` DD from `STEP6` and observe the OPEN failure message and `RC=16`.
- Change `MACRF=GM`/`PM` to locate mode (`GL`/`PL`) and adapt the `GET`/`PUT` logic.

## License

[MIT](LICENSE)
