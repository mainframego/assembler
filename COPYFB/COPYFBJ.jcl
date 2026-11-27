//COPYFBJ  JOB (ACCT),'EXAMPLE1',CLASS=A,MSGCLASS=X,
//             MSGLEVEL=(1,1),NOTIFY=&SYSUID,COND=(0,NE)
//*====================================================================
//* JOB......: COPYFBJ
//* FUNCTION.: ASSEMBLES (ASMA90), LINK-EDITS (IEWL) AND RUNS THE
//*            HLASM PROGRAM COPYFB, WHICH COPIES THE DATA SET ON
//*            DDNAME INFILE (RECFM=FB,LRECL=80) TO DDNAME OUTFILE.
//*
//* CUSTOMIZE: - THE HLQ SYMBOL WITH YOUR DATA SET PREFIX;
//*            - THE JOB CARD (ACCOUNT, CLASSES) FOR YOUR SITE.
//*
//* PREREQS..: &HLQ..ASM         FB/80 PDS WITH MEMBER COPYFB
//*            &HLQ..LOAD        PDS/PDSE RECFM=U (LOAD LIBRARY)
//*====================================================================
//         SET HLQ=USERID
//*
//*--------------------------------------------------------------------
//* STEP 1 - DELETE THE INPUT AND OUTPUT DATA SETS FROM A PREVIOUS RUN
//*          (DISP=MOD,DELETE DOES NOT FAIL IF THE DATA SET IS MISSING)
//*--------------------------------------------------------------------
//STEP1    EXEC PGM=IEFBR14
//DD1      DD DSN=&HLQ..DATA.INPUT,DISP=(MOD,DELETE,DELETE),
//         UNIT=SYSALLDA,SPACE=(TRK,(0))
//DD2      DD DSN=&HLQ..DATA.OUTPUT,DISP=(MOD,DELETE,DELETE),
//         UNIT=SYSALLDA,SPACE=(TRK,(0))
//*
//*--------------------------------------------------------------------
//* STEP 2 - ALLOCATE THE INPUT DATA SET
//*--------------------------------------------------------------------
//STEP2    EXEC PGM=IEFBR14
//DD3      DD DSN=&HLQ..DATA.INPUT,
//         DISP=(NEW,CATLG,DELETE),
//         UNIT=SYSALLDA,SPACE=(TRK,(15,15),RLSE),
//         DCB=(RECFM=FB,LRECL=80,BLKSIZE=0)
//*
//*--------------------------------------------------------------------
//* STEP 3 - WRITE TEST RECORDS TO THE INPUT DATA SET
//*--------------------------------------------------------------------
//STEP3    EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=*
//SYSIN    DD DUMMY
//SYSUT1   DD *
LINE01 WORD11 WORD12
LINE02 WORD21 WORD22
//SYSUT2   DD DISP=SHR,DSN=&HLQ..DATA.INPUT
//*--------------------------------------------------------------------
//* STEP 4 - ASSEMBLY WITH THE HIGH LEVEL ASSEMBLER
//*          SYSLIB : MACRO LIBRARIES (DCB, OPEN, GET, DCBD, ...)
//*          SYSIN  : PROGRAM SOURCE
//*          SYSLIN : GENERATED OBJECT MODULE (TEMPORARY &&OBJ)
//*--------------------------------------------------------------------
//ASM      EXEC PGM=ASMA90,PARM='OBJECT,NODECK,XREF(SHORT)'
//SYSLIB   DD DSN=SYS1.MACLIB,DISP=SHR
//         DD DSN=SYS1.MODGEN,DISP=SHR
//SYSUT1   DD UNIT=SYSALLDA,SPACE=(CYL,(1,1))
//SYSPRINT DD SYSOUT=*
//SYSLIN   DD DSN=&&OBJ,DISP=(NEW,PASS),UNIT=SYSALLDA,
//         SPACE=(TRK,(5,5)),
//         DCB=(RECFM=FB,LRECL=80,BLKSIZE=3200)
//SYSIN    DD DSN=&HLQ..ASM(COPYFB),DISP=SHR
//*
//*--------------------------------------------------------------------
//* STEP 5 - LINK-EDIT (BINDER). RUNS ONLY IF THE ASSEMBLY ENDED
//*          WITH RC <= 4. CREATES MEMBER COPYFB IN THE LOAD LIBRARY.
//*--------------------------------------------------------------------
//LKED     EXEC PGM=IEWL,PARM='LIST,MAP,XREF',COND=(4,LT,ASM)
//SYSPRINT DD SYSOUT=*
//SYSUT1   DD UNIT=SYSALLDA,SPACE=(CYL,(1,1))
//SYSLIN   DD DSN=&&OBJ,DISP=(OLD,DELETE)
//SYSLMOD  DD DSN=&HLQ..LOAD(COPYFB),DISP=SHR
//*
//*--------------------------------------------------------------------
//* STEP 6 - RUN PROGRAM COPYFB. RUNS ONLY IF ASM AND LKED ENDED
//*          WITH RC <= 4.
//*          INFILE : DATA SET READ     (RECFM=FB,LRECL=80)
//*          OUTFILE: DATA SET CREATED WITH THE SAME DCB AS THE INPUT
//*                   (BLKSIZE=0 -> OPTIMAL BLOCK SIZE CALCULATED BY
//*                   THE SYSTEM, 27920 ON A 3390 DISK)
//*--------------------------------------------------------------------
//STEP6       EXEC PGM=COPYFB,COND=((4,LT,ASM),(4,LT,LKED))
//STEPLIB  DD DSN=&HLQ..LOAD,DISP=SHR
//INFILE   DD DSN=&HLQ..DATA.INPUT,DISP=SHR
//OUTFILE  DD DSN=&HLQ..DATA.OUTPUT,
//         DISP=(NEW,CATLG,DELETE),
//         UNIT=SYSALLDA,SPACE=(TRK,(15,15),RLSE),
//         DCB=(RECFM=FB,LRECL=80,BLKSIZE=0)
//SYSUDUMP DD SYSOUT=*
//
