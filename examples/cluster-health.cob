       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLUSTER-HEALTH.
      *OpenClaw Cluster Health Summary (COBOL)
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-NODE-1   PIC X(20) VALUE "localhost:8080".
       01 WS-NODE-2   PIC X(20) VALUE "localhost:8081".
       01 WS-STATUS-1 PIC 9(3)  VALUE 200.
       01 WS-STATUS-2 PIC 9(3)  VALUE 503.
       PROCEDURE DIVISION.
       MAIN-PARA.
           DISPLAY "node " WS-NODE-1 " -> HTTP " WS-STATUS-1
           DISPLAY "node " WS-NODE-2 " -> HTTP " WS-STATUS-2
           STOP RUN.
