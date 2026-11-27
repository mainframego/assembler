//COPYFBJ  JOB (ACCT),'EXEMPLO1',CLASS=A,MSGCLASS=X,
//             MSGLEVEL=(1,1),NOTIFY=&SYSUID,COND=(0,NE)
//*====================================================================
//* JOB......: COPYFBJ
//* FUNCAO...: COMPILA (ASMA90), LINKEDITA (IEWL) E EXECUTA O
//*            PROGRAMA HLASM COPYFB, QUE COPIA O ARQUIVO DO DDNAME
//*            ENTRADA (RECFM=FB,LRECL=80) PARA O DDNAME SAIDA.
//*
//* AJUSTAR..: - O SIMBOLO HLQ COM O SEU PREFIXO DE DATASETS;
//*            - O CARTAO JOB (CONTA, CLASSES) CONFORME A INSTALACAO.
//*
//* PRE-REQ..: &HLQ..ASM         PDS FB/80 COM O MEMBRO COPYFB
//*            &HLQ..LOAD        PDS/PDSE RECFM=U (BIBLIOTECA LOAD)
//*====================================================================
//         SET HLQ=USERID
//*
//*--------------------------------------------------------------------
//* STEP 1 - EXCLUI O ARQUIVO DE ENTRADA E SAIDA DE EXECUCAO ANTERIOR
//*           (DISP=MOD,DELETE NAO FALHA SE O DATASET NAO EXISTIR)
//*--------------------------------------------------------------------
//STEP1    EXEC PGM=IEFBR14
//DD1      DD DSN=&HLQ..ARQ.ENTRADA,DISP=(MOD,DELETE,DELETE),
//         UNIT=SYSALLDA,SPACE=(TRK,(0))
//DD2      DD DSN=&HLQ..ARQ.SAIDA,DISP=(MOD,DELETE,DELETE),
//         UNIT=SYSALLDA,SPACE=(TRK,(0))
//*
//*--------------------------------------------------------------------
//* STEP2 2 - ALLOCA O ARQUIVO DE ENTRADA
//*--------------------------------------------------------------------
//STEP2    EXEC PGM=IEFBR14
//DD3      DD DSN=&HLQ..ARQ.ENTRADA,
//         DISP=(NEW,CATLG,DELETE),
//         UNIT=SYSALLDA,SPACE=(TRK,(15,15),RLSE),
//         DCB=(RECFM=FB,LRECL=80,BLKSIZE=0)
//*
//*--------------------------------------------------------------------
//* STEP3 3 - INSERI REGISTRO DATASET ENTRADA
//*--------------------------------------------------------------------
//STEP3    EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=*
//SYSIN    DD DUMMY
//SYSUT1   DD *
LINE01 WORD11 WORD12
LINE02 WORD21 WORD22
//SYSUT2   DD DISP=SHR,DSN=&HLQ..ARQ.ENTRADA
//*--------------------------------------------------------------------
//* STEP 4 - MONTAGEM (ASSEMBLY) COM O HIGH LEVEL ASSEMBLER
//*           SYSLIB : BIBLIOTECAS DE MACROS (DCB, OPEN, GET, DCBD..)
//*           SYSIN  : FONTE DO PROGRAMA
//*           SYSLIN : MODULO OBJETO GERADO (TEMPORARIO &&OBJ)
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
//* STEP 5 - LINKEDICAO (BINDER). SO EXECUTA SE O ASM TERMINOU COM
//*           RC <= 4. GERA O MEMBRO COPYFB NA BIBLIOTECA LOAD.
//*--------------------------------------------------------------------
//LKED     EXEC PGM=IEWL,PARM='LIST,MAP,XREF',COND=(4,LT,ASM)
//SYSPRINT DD SYSOUT=*
//SYSUT1   DD UNIT=SYSALLDA,SPACE=(CYL,(1,1))
//SYSLIN   DD DSN=&&OBJ,DISP=(OLD,DELETE)
//SYSLMOD  DD DSN=&HLQ..LOAD(COPYFB),DISP=SHR
//*
//*--------------------------------------------------------------------
//* STEP 6 - EXECUCAO DO PROGRAMA COPYFB. SO EXECUTA SE ASM E LKED
//*           TERMINARAM COM RC <= 4.
//*           ENTRADA: ARQUIVO LIDO   (RECFM=FB,LRECL=80)
//*           SAIDA  : ARQUIVO GERADO COM A MESMA DCB DA ENTRADA
//*                    (BLKSIZE=0 -> BLOCAGEM OTIMA CALCULADA PELO
//*                    SISTEMA, 27920 EM DISCO 3390)
//*--------------------------------------------------------------------
//STEP6       EXEC PGM=COPYFB,COND=((4,LT,ASM),(4,LT,LKED))
//STEPLIB  DD DSN=&HLQ..LOAD,DISP=SHR
//ENTRADA  DD DSN=&HLQ..ARQ.ENTRADA,DISP=SHR
//SAIDA    DD DSN=&HLQ..ARQ.SAIDA,
//         DISP=(NEW,CATLG,DELETE),
//         UNIT=SYSALLDA,SPACE=(TRK,(15,15),RLSE),
//         DCB=(RECFM=FB,LRECL=80,BLKSIZE=0)
//SYSUDUMP DD SYSOUT=*
//
