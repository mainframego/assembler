*=====================================================================
*
*  PROGRAMA.: COPYFB
*  LINGUAGEM: HLASM - HIGH LEVEL ASSEMBLER PARA Z/OS
*
*  OBJETIVO.: LER SEQUENCIALMENTE O ARQUIVO DO DDNAME ENTRADA
*             (RECFM=FB, LRECL=80) E GRAVAR CADA REGISTRO LIDO NO
*             ARQUIVO DO DDNAME SAIDA, COM A MESMA DCB DA ENTRADA
*             (RECFM=FB, LRECL=80).
*
*  ACESSO...: QSAM (QUEUED SEQUENTIAL ACCESS METHOD), MACROS DCB,
*             OPEN, GET, PUT E CLOSE, EM MODO MOVE (GM/PM).
*
*  DDNAMES..: ENTRADA - ARQUIVO DE ENTRADA  (INPUT)
*             SAIDA   - ARQUIVO DE SAIDA    (OUTPUT)
*
*  RETORNO..: RC = 00 - PROCESSAMENTO NORMAL
*             RC = 16 - ERRO NA ABERTURA DE ENTRADA OU SAIDA
*
*  MENSAGEM.: AO FINAL E EMITIDO UM WTO COM A QUANTIDADE DE
*             REGISTROS COPIADOS (APARECE NO JOBLOG / JESMSGLG).
*
*  REGISTRADORES UTILIZADOS:
*             R2  - PONTEIRO PARA A DCB (TESTE DE ABERTURA)
*             R5  - CONTADOR DE REGISTROS COPIADOS
*             R11 - AUXILIAR PARA ENCADEAMENTO DA SAVE AREA
*             R12 - REGISTRADOR BASE DO PROGRAMA
*             R13 - ENDERECO DA SAVE AREA DESTE PROGRAMA
*             R14 - ENDERECO DE RETORNO AO CHAMADOR
*             R15 - ENDERECO DE ENTRADA / CODIGO DE RETORNO
*
*  ATRIBUTOS: AMODE 31 / RMODE 24 (AS DCBS DO QSAM PRECISAM ESTAR
*             ABAIXO DA LINHA DE 16MB). NAO REENTRANTE (AS DCBS E A
*             SAVE AREA FICAM DENTRO DO PROPRIO MODULO).
*
*=====================================================================
COPYFB   CSECT                    Inicio da secao de controle COPYFB
COPYFB   AMODE 31                 Executa em enderecamento 31 bits
COPYFB   RMODE 24                 Carregado abaixo da linha (16MB)
*
*---------------------------------------------------------------------
*  CONVENCAO DE LIGACAO (ENTRADA) - SALVA REGISTRADORES DO CHAMADOR,
*  ESTABELECE O REGISTRADOR BASE E ENCADEIA AS SAVE AREAS.
*---------------------------------------------------------------------
         STM   R14,R12,12(R13)    Salva R14 a R12 na SA do chamador
         LR    R12,R15            R12 recebe o endereco de entrada
         USING COPYFB,R12         R12 passa a ser o registrador base
         LA    R11,SAVEAREA       R11 aponta para a nossa save area
         ST    R13,4(,R11)        Nossa SA aponta p/ SA do chamador
         ST    R11,8(,R13)        SA do chamador aponta p/ a nossa
         LR    R13,R11            R13 aponta para a nossa save area
*
*---------------------------------------------------------------------
*  INICIALIZACAO DO CONTADOR DE REGISTROS
*---------------------------------------------------------------------
         SR    R5,R5              Zera o contador de registros (R5)
*
*---------------------------------------------------------------------
*  ABERTURA DOS ARQUIVOS
*  A MACRO OPEN ABRE A DCB ENTRADA PARA LEITURA (INPUT) E A DCB SAIDA
*  PARA GRAVACAO (OUTPUT). OS ATRIBUTOS NAO CODIFICADOS NA DCB (EX.:
*  BLKSIZE) SAO OBTIDOS DO JCL OU DO LABEL DO DATASET.
*---------------------------------------------------------------------
         OPEN  (ENTRADA,(INPUT),SAIDA,(OUTPUT))
*
*---------------------------------------------------------------------
*  VERIFICA SE AS DUAS DCBS FORAM REALMENTE ABERTAS.
*  O BIT DCBOFOPN DO CAMPO DCBOFLGS FICA LIGADO QUANDO O OPEN TEM
*  SUCESSO. O MAPEAMENTO DOS CAMPOS E FEITO PELA DSECT IHADCB
*  (GERADA PELA MACRO DCBD NO FINAL DO PROGRAMA).
*---------------------------------------------------------------------
         LA    R2,ENTRADA         R2 recebe o endereco da DCB ENTRADA
         USING IHADCB,R2          Mapeia a DCB com a DSECT IHADCB
         TM    DCBOFLGS,DCBOFOPN  Testa o bit de "DCB aberta"
         BZ    ERROPEN            Bit desligado: erro no OPEN
         LA    R2,SAIDA           R2 recebe o endereco da DCB SAIDA
         TM    DCBOFLGS,DCBOFOPN  Testa o bit de "DCB aberta"
         BZ    ERROPEN            Bit desligado: erro no OPEN
         DROP  R2                 Encerra o mapeamento via R2
*
*---------------------------------------------------------------------
*  LACO PRINCIPAL: LE UM REGISTRO DA ENTRADA E GRAVA NA SAIDA.
*  NO MODO MOVE (MACRF=GM/PM) O QSAM COPIA O REGISTRO PARA A AREA
*  INFORMADA (REGISTRO) E, NO PUT, COPIA DA AREA PARA O BUFFER.
*  QUANDO NAO HOUVER MAIS REGISTROS, O QSAM DESVIA AUTOMATICAMENTE
*  PARA A ROTINA INDICADA NO PARAMETRO EODAD DA DCB (FIMARQ).
*  OBS.: GET/PUT ALTERAM R0, R1, R14 E R15 - POR ISSO O CONTADOR
*  ESTA EM R5.
*---------------------------------------------------------------------
LEITURA  DS    0H                 Ponto de inicio do laco de leitura
         GET   ENTRADA,REGISTRO   Le o proximo registro p/ REGISTRO
         AHI   R5,1               Soma 1 ao contador de registros
         PUT   SAIDA,REGISTRO     Grava o conteudo de REGISTRO
         B     LEITURA            Volta para ler o proximo registro
*
*---------------------------------------------------------------------
*  FIM DE ARQUIVO (EODAD): FECHA OS ARQUIVOS, EXIBE A QUANTIDADE DE
*  REGISTROS COPIADOS E TERMINA COM RC=0.
*---------------------------------------------------------------------
FIMARQ   DS    0H                 Desvio do QSAM no fim da ENTRADA
         CLOSE (ENTRADA,,SAIDA)   Fecha ENTRADA e SAIDA (grava buffer)
         CVD   R5,DWORK           Converte contador p/ decimal compac.
         UNPK  WTOCNT,DWORK       Descompacta p/ zonado (9 digitos)
         OI    WTOCNT+L'WTOCNT-1,X'F0'  Ajusta sinal do ultimo digito
         WTO   MF=(E,WTOMSG)      Exibe a mensagem com o total lido
         SR    R15,R15            Codigo de retorno = 0 (sucesso)
         B     RETORNO            Desvia para a rotina de retorno
*
*---------------------------------------------------------------------
*  ERRO NA ABERTURA: FECHA O QUE ESTIVER ABERTO (O CLOSE IGNORA DCB
*  NAO ABERTA), EMITE MENSAGEM E TERMINA COM RC=16.
*---------------------------------------------------------------------
ERROPEN  DS    0H                 Rotina de tratamento de erro no OPEN
         CLOSE (ENTRADA,,SAIDA)   Fecha as DCBs que estiverem abertas
         WTO   'COPYFB - ERRO NA ABERTURA DE ENTRADA OU SAIDA'
         LA    R15,16             Codigo de retorno = 16 (erro grave)
*
*---------------------------------------------------------------------
*  CONVENCAO DE LIGACAO (SAIDA) - RESTAURA OS REGISTRADORES DO
*  CHAMADOR E DEVOLVE O CONTROLE COM O CODIGO DE RETORNO EM R15.
*---------------------------------------------------------------------
RETORNO  DS    0H                 Ponto unico de saida do programa
         L     R13,4(,R13)        R13 volta a apontar p/ SA chamador
         L     R14,12(,R13)       Restaura o endereco de retorno
         LM    R0,R12,20(R13)     Restaura R0-R12 (R15 mantem o RC)
         BR    R14                Devolve o controle ao chamador
*
*=====================================================================
*  AREA DE DADOS
*=====================================================================
SAVEAREA DS    18F                Save area deste programa (72 bytes)
DWORK    DS    D                  Area de trabalho p/ o CVD (8 bytes)
REGISTRO DS    CL80               Area do registro lido / gravado
*
*---------------------------------------------------------------------
*  MENSAGEM WTO NO FORMATO LISTA (MF=L) MONTADA MANUALMENTE:
*  +0 TAMANHO (2 BYTES) / +2 FLAGS MCS (2 BYTES) / +4 TEXTO
*---------------------------------------------------------------------
WTOMSG   DS    0F                 Alinha a lista do WTO em fullword
         DC    AL2(WTOFIM-WTOMSG) Tamanho total: cabecalho + texto
         DC    XL2'0000'          Flags MCS (nenhuma opcao especial)
         DC    C'COPYFB - REGISTROS COPIADOS: '  Texto fixo
WTOCNT   DC    CL9' '             Quantidade de registros (zonado)
WTOFIM   EQU   *                  Marca o fim da mensagem
*
*---------------------------------------------------------------------
*  DCB DO ARQUIVO DE ENTRADA (DDNAME ENTRADA)
*---------------------------------------------------------------------
ENTRADA  DCB   DDNAME=ENTRADA,     Nome do DD no JCL                   X
               DSORG=PS,           Organizacao sequencial fisica       X
               MACRF=GM,           GET em modo move (move mode)        X
               RECFM=FB,           Registro fixo e blocado             X
               LRECL=80,           Tamanho do registro: 80 bytes       X
               EODAD=FIMARQ        Rotina executada no fim de arq.
*
*---------------------------------------------------------------------
*  DCB DO ARQUIVO DE SAIDA (DDNAME SAIDA) - MESMA DCB DA ENTRADA.
*  O BLKSIZE NAO E CODIFICADO: VEM DO JCL OU E CALCULADO PELO
*  SISTEMA (SYSTEM DETERMINED BLOCKSIZE) QUANDO BLKSIZE=0.
*---------------------------------------------------------------------
SAIDA    DCB   DDNAME=SAIDA,       Nome do DD no JCL                   X
               DSORG=PS,           Organizacao sequencial fisica       X
               MACRF=PM,           PUT em modo move (move mode)        X
               RECFM=FB,           Registro fixo e blocado             X
               LRECL=80            Tamanho do registro: 80 bytes
*
*---------------------------------------------------------------------
*  POOL DE LITERAIS
*---------------------------------------------------------------------
         LTORG                    Literais gerados pelas macros
*
*---------------------------------------------------------------------
*  EQUATES DOS REGISTRADORES GERAIS
*---------------------------------------------------------------------
R0       EQU   0                  Registrador geral 0
R1       EQU   1                  Registrador geral 1
R2       EQU   2                  Registrador geral 2
R3       EQU   3                  Registrador geral 3
R4       EQU   4                  Registrador geral 4
R5       EQU   5                  Registrador geral 5
R6       EQU   6                  Registrador geral 6
R7       EQU   7                  Registrador geral 7
R8       EQU   8                  Registrador geral 8
R9       EQU   9                  Registrador geral 9
R10      EQU   10                 Registrador geral 10
R11      EQU   11                 Registrador geral 11
R12      EQU   12                 Registrador geral 12
R13      EQU   13                 Registrador geral 13
R14      EQU   14                 Registrador geral 14
R15      EQU   15                 Registrador geral 15
*
*---------------------------------------------------------------------
*  DSECT IHADCB - MAPEAMENTO DOS CAMPOS DA DCB (DCBOFLGS, ETC.).
*  DEVE FICAR NO FINAL, POIS GERA UMA DSECT (NAO OCUPA ESPACO).
*---------------------------------------------------------------------
         DCBD  DSORG=PS,DEVD=DA   Gera a DSECT IHADCB p/ DSORG=PS
*
         END   COPYFB             Fim do fonte; ponto de entrada
