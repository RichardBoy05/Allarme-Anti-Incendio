# ===================================================================
# Allarme Anti-Incendio - Progetto MIPS
# Autore: Richard Meoli, matricola 1099274
# Corso: "Calcolatori Elettronici", Università degli Studi di Bergamo
# Anno accademico: 2024/25
# ===================================================================


.data  # ======================= SEZIONE DATI =======================

# ----------------------- VARIABILI E COSTANTI ----------------------

DELAY_COUNT:                    .word 10000000  # numero di iterazioni per il timer (valore giustificato nella subroutine delay_1s)
temp_contatore:                 .half 0         # contatore dei secondi consecutivi con T > 60 in almeno 2 sensori (16 bit per un massimo di circa 9 ore, sufficienti per un intervento umano)
reset_contatore:                .byte 0         # contatore dei secondi consecutivi con T < 60 e no fumo
record_count:                   .byte 0         # contatore dei sensori scritti in RECORD
indice_tabella_sim:             .byte 0         # indice riga corrente nella tabella di simulazione
dimensione_tabella_sim:         .byte 18        # numero di stati (righe) nella tabella di simulazione
vvf_timer:                      .byte 0         # timer per disattivazione chiamata VVFF (max 1s)
modalita_simulazione:           .byte 1         # 0 = manuale, 1 = automatica
MIN_SENSORI:                    .byte 1         # numero minimo di sensori nel sistema
MAX_SENSORI:                    .byte 16        # numero massimo di sensori nel sistema
NUM_SENSORI_ATTIVI:             .byte 16        # default a 16, ma l'utente può cambiarlo
SOGLIA_TEMPERATURA_ESTINZIONE:  .byte 60        # temperatura per l'attivazione dell'impianto di estinzione 
SOGLIA_RECORD:                  .byte 40        # temperatura per salvataggio in RECORD
SECONDI_RESET:                  .byte 5         # secondi per il reset completo del sistema
SECONDI_ATTIVAZIONE_ACQUA:      .byte 5         # secondi (con T > 60 in almeno 2 sensori) trascorsi i quali viene attivata l'acqua
MIN_SENSORI_PER_ACQUA:          .byte 2         # numero minimo di sensori con temperatura eccessiva affinché possa essere attivata l'acqua

# -------------------- ZONE DI MEMORIA DEL SISTEMA ---------------------

.align 2                    # allineamento a livello di parola (4 byte)

ALLARMS:     .space 4       # 16 sensori * 2 bit = 32 bit (4 byte)

TEMPERATURE: .space 64      # 16 sensori * 4 byte (2 per ID, 2 per temp) = 64 byte

RECORD:      .space 32      # max 16 sensori * 2 byte (ID sensore) = 32 byte

COMMAND:     .byte 0        # 1 byte per i 3 bit di comando

# ------------------- TABELLA DI SIMULAZIONE PRECARICATA --------------------
# Questa tabella è adibita alla simulazione automatica del progetto. Ogni riga
# rappresenta uno stato del sistema in un dato secondo, al fine di testare in
# sequenza tutti i casi previsti dalla traccia. Si noti che affinché possano
# essere verificati appieno è preferibile utilizzare tutti i 16 sensori disponibili.
#
# Struttura di ogni riga (36 byte totali):
#   - 4 byte (.word):  Valore base per l'area ALLARMS.
#     I bit di FUMO vengono letti direttamente da qui. I bit di TEMPERATURA
#     di questa word vengono invece ignorati e ricalcolati dinamicamente.
#
#   - 32 byte (.half * 16): Valori di temperatura (in Celsius) per i 16 sensori.
#     Questi valori vengono usati sia per popolare la memoria
#     TEMPERATURE, sia per calcolare i bit di stato in ALLARMS.
# ---------------------------------------------------------------------------

.align 2                    # allineamento a livello di parola (4 byte)
tabella_simulazione:

# condizioni normali, il contatore di reset si incrementa
    .word 0x00000000
    .half 20, 25, 22, 19, 23, 20, 21, 22, 39, 32, 20, 21, 22, 19, 23, 33

# il contatore di reset continua a salire
    .word 0x00000000
    .half 21, 38, 23, 20, 22, 31, 20, 23, 20, 22, 21, 27, 23, 20, 22, 21

# attivazione SIRENA per fumo rilevato (sensore 5)
    .word 0x00000800
    .half 25, 24, 26, 23, 25, 35, 24, 26, 23, 25, 24, 26, 23, 25, 24, 26
    
# la SIRENA rimane attiva anche se il fumo scompare (logica di persistenza)
    .word 0x00000000
    .half 22, 21, 23, 21, 24, 28, 22, 23, 21, 24, 22, 23, 21, 24, 22, 23

# avvio timer per l'acqua (T > 60 su sensori 1 e 10); temp_contatore = 1
    .word 0x00100002
    .half 30, 65, 32, 31, 33, 35, 30, 32, 31, 33, 70, 31, 33, 35, 30, 32

# il timer per l'acqua continua; temp_contatore = 2
    .word 0x00100002
    .half 31, 66, 33, 32, 34, 36, 31, 33, 32, 34, 71, 32, 34, 36, 31, 33

# il timer per l'acqua continua; temp_contatore = 3
    .word 0x00100002
    .half 32, 67, 34, 33, 35, 37, 32, 34, 33, 35, 72, 33, 35, 37, 32, 34

# il timer per l'acqua continua; temp_contatore = 4
    .word 0x00100002
    .half 33, 68, 35, 34, 36, 38, 33, 35, 34, 36, 73, 34, 36, 38, 33, 35

# il timer per l'acqua continua; temp_contatore = 5
    .word 0x00100002
    .half 34, 69, 36, 35, 37, 39, 34, 36, 35, 37, 74, 35, 37, 39, 34, 36

# attivazione acqua e scrittura in RECORD (sensori con T > 40: 1, 3, 10, 12) mentre l'acqua è attiva
    .word 0x00100000
    .half 35, 55, 37, 42, 38, 40, 35, 37, 36, 38, 75, 36, 48, 40, 35, 37

# gli allarmi persistono; inizio conteggio per il reset (reset_contatore=1)
    .word 0x00000000
    .half 50, 52, 48, 45, 49, 46, 50, 48, 45, 49, 58, 45, 49, 46, 50, 48

# evento critico (fumo+temp su sensore 15), attivazione immediata VVFF
    .word 0xC0000000
    .half 40, 41, 42, 39, 43, 40, 41, 42, 39, 43, 40, 41, 42, 39, 43, 95

# disattivazione VVFF dopo 1s; gli altri allarmi persistono
    .word 0x00000000
    .half 30, 31, 32, 29, 33, 30, 31, 32, 29, 33, 30, 31, 32, 29, 33, 30

# il timer di reset continua; reset_contatore = 2
    .word 0x00000000
    .half 28, 29, 30, 27, 31, 28, 29, 30, 27, 31, 28, 29, 30, 27, 31, 28

# il timer di reset continua; reset_contatore = 3
    .word 0x00000000
    .half 26, 27, 28, 25, 29, 26, 27, 28, 25, 29, 26, 27, 28, 25, 29, 26

# il timer di reset continua; reset_contatore = 4
    .word 0x00000000
    .half 24, 25, 26, 23, 27, 24, 25, 26, 23, 27, 24, 25, 26, 23, 27, 24

# RESET COMPLETO del sistema dopo 5s; reset_contatore = 5
    .word 0x00000000
    .half 22, 23, 24, 21, 25, 22, 23, 24, 21, 25, 22, 23, 24, 21, 25, 22

# verifica che il sistema sia tornato allo stato iniziale pulito
    .word 0x00000000
    .half 20, 21, 22, 19, 23, 20, 21, 22, 19, 23, 20, 21, 22, 19, 23, 20


# ----------------------- MESSAGGI D'INTERAZIONE UTENTE -----------------------
msg_benvenuto:                  .asciiz "\n=== Benvenuto nel sistema di Allarme Anti-Incendio ===\n"
msg_inserisci_sensori:          .asciiz "Inserisci il numero di sensori del sistema (1-16): "
msg_errore_inserimento_sensori: .asciiz "Valore non valido, riprova.\n"
msg_scegli_modalita:            .asciiz "\nScegli la modalita' di simulazione:\n  0 -> Inserimento manuale dei dati ad ogni secondo\n  1 -> Simulazione automatica da tabella precaricata\nScelta: "
msg_errore_modalita:            .asciiz "Modalita' non valida. Inserire 0 o 1.\n"
msg_sim_manuale_start:          .asciiz "\n--- SIMULAZIONE MANUALE (secondo in corso) ---\n"
msg_sim_sensore_n:              .asciiz "Sensore "
msg_sim_fumo:                   .asciiz ": Fumo rilevato? (1=Si, 0=No): "
msg_sim_temp_valore:            .asciiz ": Valore esatto temperatura (in C): "
msg_sirena:                     .asciiz "--- ATTENZIONE: Sirena attivata! ---\n"
msg_acqua:                      .asciiz "--- ATTENZIONE: Impianto di estinzione attivato! ---\n"
msg_vvff:                       .asciiz "--- ATTENZIONE: Chiamata ai VVFF inviata! ---\n"
msg_reset_sistema:              .asciiz "--- INFO: Condizioni normali ripristinate. Sistema in reset. ---\n"
msg_stato_header:               .asciiz "\n\n=================== STATO AL SECONDO ATTUALE ===================\n"
msg_dettaglio_sensori:          .asciiz "--- Dettaglio Sensori ---\n"
msg_sensore_id_header:          .asciiz "Sensore "
msg_fumo_stato:                 .asciiz " | Fumo: "
msg_stato_si:                   .asciiz "SI"
msg_stato_no:                   .asciiz "NO"
msg_temp_stato:                 .asciiz " | Temp: "
msg_gradi_celsius:              .asciiz " C"
msg_stato_contatori:            .asciiz "\n\n--- Contatori di Stato ---\nTemp > 60 C in almeno 2 sensori per "
msg_contatore_secondi:          .asciiz " secondi | Reset in corso per "
msg_secondi:                    .asciiz " secondi\n"
msg_stato_record_header:        .asciiz "\n\n--- ID dei sensori con T > 40 C (se estinzione attiva) ---\n"
msg_stato_no_record:            .asciiz "Nessuno o estinzione ad acqua non attiva."
msg_stato_sensore_id:           .asciiz " "
new_line:                       .asciiz "\n"
msg_stato_footer:               .asciiz "\n===============================================================\n"

# ----------------------- MESSAGGI PER GESTIONE DELLE ECCEZIONI -----------------------
msg_errore_critico:             .asciiz "\n\n===== ERRORE CRITICO DI SISTEMA RILEVATO =====\nIl sistema non può continuare in modo sicuro. Esecuzione terminata.\n"
msg_errore_code:                .asciiz "Codice Errore (ExcCode): "
msg_errore_epc:                 .asciiz "\nIndirizzo dell'errore (EPC, in base 10): "



.text  # ======================= SEZIONE CODICE =======================

.globl main
main:   
    li $v0, 4                       # imposto la scrittura di una stringa 
    la $a0, msg_benvenuto           # carico l'indirizzo del messaggio di testo
    syscall                         # stampa
    
    jal richiedi_numero_sensori     # chiamo la procedura per la richesta del numero di sensori
    jal scegli_modalita_simulazione # chiamo la procedura per scegliere la modalità di simulazione

main_loop:                          # loop delle operazioni da eseguire ogni secondo

    # ---------------------------------------------------
    # BLOCCO DI TEST PER IL GESTORE DI ECCEZIONI
    # È possibile decommentare una delle due sezioni di test alla volta
    # per verificare il comportamento del gestore di eccezioni.
    #
    # --- TEST 1: overflow aritmetico (ExcCode 12) ---
    # li $t0, 0x7FFFFFFF      # carica il massimo intero positivo
    # add $t0, $t0, 1         # questa istruzione causerà un'eccezione di overflow
    #
    # --- TEST 2: errore di indirizzamento (ExcCode 5) ---
    # li $t0, 1               # indirizzo di memoria dispari (non allineato per una word)
    # sw $zero, 0($t0)        # questo causerà un'eccezione di store non allineato
    #
    # FINE BLOCCO DI TEST
    # ---------------------------------------------------


    # inizio del main loop: chiamo tutte le subroutine necessarie
    
    jal gestisci_simulazione 
    jal analizza_ALLARMS
    jal aggiorna_COMMAND
    jal analizza_TEMPERATURE
    jal gestisci_contatori_temporali
    jal stampa_stato
    
    lb $t0, modalita_simulazione    # carico il byte che rappresenta la modalità di simulazione (0 = manuale, 1 = automatica)
    beq $t0, $zero, skip_delay      # se 1 (automatica) attendo un secondo, altrimenti (0, manuale) riprendo subito il loop
    jal delay_1s                    # attendo 1 secondo

skip_delay:
    j main_loop                     # riprendo il loop



# -------------------------------------------
# Subroutine: analizza_ALLARMS
# Imposta: 
#   $s0 = fumoPresente (1 se c'è almeno un sensore con fumo, altrimenti 0)
#   $s1 = tempAltaCount (quanti sensori hanno temp > 60)
#   $s2 = fumoETempStessoSensore (1 se almeno un sensore ha sia fumo che temp > 60, altrimenti 0)
#
#   Bit per sensore [bit alto: fumo rilevato; bit basso: temperatura eccessiva],
#   da cui si ha che: [00] <-> nulla, [01]: solo temp > 60, [10]: solo fumo, [11]: entrambi
# -------------------------------------------
analizza_ALLARMS:

    # inizializzo i registri di stato

    li $s0, 0                   # fumoPresente = 0 (false)
    li $s1, 0                   # tempAltaCount = 0
    li $s2, 0                   # fumoETempStessoSensore = 0 (false)

    lw $t0, ALLARMS             # carico i 32 bit di ALLARMS in $t0
    li $t1, 0                   # inizializzo $t1 come indice del sensore corrente (i)
    lb $t5, NUM_SENSORI_ATTIVI  # carico in $t5 il numero totale di sensori da analizzare

loop_analizza:

    # calcolo lo scorrimento necessario per portare i bit del sensore corrente a destra
    mul $t2, $t1, 2             # $t2 = i * 2 (dove 2 è il numero di bit per sensore)

    # estraggo i 2 bit di stato del sensore corrente
    srlv $t3, $t0, $t2          # scorro l'intera parola ALLARMS a destra di i * 2 posizioni
    andi $t3, $t3, 0x3          # isolo i 2 bit di interesse con una maschera (0b11)

    # ora $t3 contiene il valore di stato (da 0 a 3 in base 10)

    # controllo il valore dello stato
    li $t4, 3                   # stato 3 (0b11): fumo + temp > 60
    beq $t3, $t4, set_fumo_temp

    li $t4, 2                   # stato 2 (0b10): solo fumo
    beq $t3, $t4, set_fumo

    li $t4, 1                   # stato 1 (0b01): solo temp > 60
    beq $t3, $t4, set_temp
    
    j continua                  # stato 0 (0b00): nulla, salta al prossimo sensore

set_fumo_temp:
    li $s0, 1                   # fumoPresente = true
    addi $s1, $s1, 1            # tempAltaCount++
    li $s2, 1                   # fumoETempStessoSensore = true
    j continua                  # salta al prossimo sensore

set_fumo:
    li $s0, 1                   # fumoPresente = true
    j continua                  # salta al prossimo sensore

set_temp:
    addi $s1, $s1, 1            # tempAltaCount++

continua:
    addi $t1, $t1, 1            # i++
    blt $t1, $t5, loop_analizza # riprendo il loop finché non ho analizzato tutti i sensori attivi

    jr $ra                      # ritorno al chiamante



# -------------------------------------------
# Subroutine: aggiorna_COMMAND
# - Legge lo stato di COMMAND e aggiunge nuovi allarmi se necessario.
# - Gli allarmi (sirena, acqua) rimangono attivi fino al reset generale.
# - La chiamata VVFF segue una sua logica di disattivazione separata.
# -------------------------------------------
aggiorna_COMMAND:
    
    lb $t0, COMMAND                     # carico in $t0 lo stato corrente di COMMAND
    
    # gestione sirena (bit 0)
    beq $s0, $zero, skip_sirena         # se $s0 (fumoPresente) == 0, non faccio nulla
    ori $t0, $t0, 0x1                   # altrimenti, attivo (o mantengo attivo) il bit della sirena con la maschera 0b001

skip_sirena:
    # gestione impianto di estinzione (bit 1)
    lb $t1, temp_contatore              # carico il valore di temp_contatore
    lb $t2, SECONDI_ATTIVAZIONE_ACQUA   # carico la soglia di secondi per l'attivazione dell'acqua (5)
    bge $t1, $t2, attiva_acqua          # se temp_contatore >= 5, attivo il bit dell'acqua (il controllo attiverà tuttavia l'impianto solo al secondo successivo, come previsto)
    beq $s2, $zero, skip_acqua          # se $s2 == 1 (fumo + temp), attivo l'acqua

attiva_acqua:
    ori $t0, $t0, 0x2                   # attivo (o mantengo attivo) il bit dell'acqua con la maschera 0b010

skip_acqua:
    # gestione chiamata ai VVFF (bit 2)
    li $t5, 4                           # maschera per il bit VVFF (0b100) 
    beq $s2, $zero, vvff_check_timer    # se non è verificata la condizione per la chiamata, gestisco il timer
    
    # caso fumo + temp eccessiva in un sensore, condizione di chiamata
    or $t0, $t0, $t5                    # attivo il bit VVFF tramite l'apposita maschera
    li $t3, 1                           # carico in $t3 il valore 1                    
    sb $t3, vvf_timer                   # imposto a 1 secondo il timer di durata della chiamata 
    j fine_vvff_check                   # salto il resto della logica VVFF, che riguarda la disattivazione della chiamata

vvff_check_timer:

    # condizione di chiamata NON verificata: controllo se la chiamata era già attiva e in tal caso la disattivo
    lb $t4, vvf_timer                   # carico in $t4 il valore del timer
    beq $t4, $zero, fine_vvff_check     # se timer già a 0 non c'era alcuna chiamata in corso, per cui esco
    
    # caso timer > 0
    addi $t4, $t4, -1                   # decremento il timer di un secondo                        
    sb $t4, vvf_timer                   # aggiorno il suo valore in memoria
    
    # se il timer è appena arrivato a 0, il bit VVFF deve essere spento;
    # altrimenti, la chiamata deve rimanere attiva per questo ciclo
    bne $t4, $zero, fine_vvff_check
    
    # timer è appena arrivato a 0, spengo il bit
    not $t5, $t5                        # inverto la maschera (da 00000100 a 11111011)
    and $t0, $t0, $t5                   # uso un AND per azzerare solo il bit dei VVFF

fine_vvff_check:
    sb $t0, COMMAND                     # scrivo in memoria il valore finale calcolato per COMMAND
    jr $ra                              # ritorno al chiamante



# -------------------------------------------
# Subroutine: analizza_TEMPERATURE
# - Imposta $s4 (tutteTempOk) a 1 se tutte le temp sono < 60, altrimenti a 0.
#   Questo flag è usato dalla logica di reset del sistema.
# - Se l'impianto di estinzione è attivo, salva in RECORD l'ID dei sensori
#   con temperatura > 40.
# -------------------------------------------
analizza_TEMPERATURE:

    # inizializzo le aree di memoria e i registri necessari
    sb $zero, record_count                  # azzero il contatore di record scritti

    li $s4, 1                               # $s4 (tutteTempOk) = 1 (true), stato di default
    la $t0, TEMPERATURE                     # $t0 = puntatore per la lettura da TEMPERATURE
    la $t3, RECORD                          # $t3 = puntatore per la scrittura in RECORD
    li $t6, 0                               # $t6 = contatore sensori scritti in RECORD
    li $t1, 0                               # $t1 = indice del sensore corrente (i)
    lb $t8, NUM_SENSORI_ATTIVI              # numero totale di sensori da analizzare

loop_temp:
    lh $t2, 2($t0)                          # carico la temperatura del sensore corrente
    lb $t7, SOGLIA_TEMPERATURA_ESTINZIONE   # carico la soglia di temperatura per l'estinzione (60)

    bge $t2, $t7, temp_non_ok_per_reset     # se la T è maggiore o uguale della soglia, salto a temp_non_ok_per_reset   
    j record_check                          # se T < della soglia, la condizione per il reset è (per ora) rispettata

temp_non_ok_per_reset:
    li $s4, 0                               # imposto tutteTempOk = 0 (false), il sistema non può resettare

record_check:                               # logica per il RECORD: controllo se salvare i sensori con T > 40 

    lb $t5, COMMAND                         # carico il byte contenuto in COMMAND
    andi $t5, $t5, 0x2                      # isolo il bit dell'acqua con la maschera 0b010
    beq $t5, $zero, skip_record_check       # se l'acqua non è attiva non va registrato alcun record

    lb $t7, SOGLIA_RECORD                   # carico la soglia di temperatura per il record (40)
    bgt $t2, $t7, salva_record              # se T > della soglia e acqua attiva, salvo il record
    j skip_record_check                     # altrimenti non lo salvo

salva_record:
    lh $t9, 0($t0)                          # leggo l'ID del sensore dall'area TEMPERATURE
    sh $t9, 0($t3)                          # scrivo l'ID del sensore in RECORD
    addi $t3, $t3, 2                        # avanzo il puntatore di RECORD
    addi $t6, $t6, 1                        # incremento il contatore dei record scritti

skip_record_check:                          # passo al prossimo sensore
    addi $t0, $t0, 4                        # avanza al prossimo blocco (ID + Temp, 4 byte) in TEMPERATURE
    addi $t1, $t1, 1                        # i++
    blt $t1, $t8, loop_temp                 # riprendo il loop finché non ho analizzato tutti i sensori

    sb $t6, record_count                    # fine del ciclo, salvo il conteggio finale dei record
    jr $ra                                  # ritorno al chiamante



# -------------------------------------------
# Subroutine: gestisci_contatori_temporali
# - Se $s1 (tempAltaCount) maggiore o uguale di 2 -> incrementa temp_contatore, altrimenti azzera
# - Se $s0 (fumoPresente) == 0 e $s4 (tutteTempOk) == 1 -> incrementa reset_contatore, altrimenti azzera
# - Se reset_contatore maggiore o uguale di 5 -> azzera COMMAND, temp_contatore e reset_contatore
# -------------------------------------------
gestisci_contatori_temporali:
    
# gestione temp_contatore
    lb $t0, MIN_SENSORI_PER_ACQUA       # carico in $t0 il numero minimo (2) di sensori con temp > 60 affinché possa essere attivata l'acqua
    blt $s1, $t0, azzera_temp_cont      # se $s1 (numero sensori con temperatura eccessiva) < 2 , azzero il relativo contatore temporale

    lh $t1, temp_contatore              # carico in $t1 il valore memorizzato in temp_contatore 
    addi $t1, $t1, 1                    # incremento il valore di 1
    sh $t1, temp_contatore              # scrivo in memoria il nuovo valore di $t1
    j controllo_reset                   # salto alla prossima parte della procedura, senza azzerare temp_contatore

azzera_temp_cont:
    sh $zero, temp_contatore            # azzero il temp_contatore

# gestione reset_contatore
controllo_reset:
    beq $s0, $zero, check_tempok        # se fumoPresente == 0 (assenza di fumo), controllo la temperatura
    j azzera_reset_cont                 # se c'è fumo, mi è sufficiente per azzerare il reset_contatore

check_tempok:                           # caso niente fumo, verifico se anche le temperature sono ok
    beq $s4, $zero, azzera_reset_cont   # se tutteTempOk == 0 (esiste almeno una temp NON ok), azzero il reset_contatore

    # altrimenti è OK: incremento il reset_contatore                               
    lb $t2, reset_contatore             # carico in $t2 il valore memorizzato in reset_contatore
    addi $t2, $t2, 1                    # incremento il valore di 1
    sb $t2, reset_contatore             # scrivo in memoria il nuovo valore di $t2
    j fase_reset                        # salto alla prossima parte della procedura, senza azzerare reset_contatore

azzera_reset_cont:
    sb $zero, reset_contatore           # azzero il reset_contatore

# reset se reset_contatore >= 5
fase_reset:
    lb $t3, reset_contatore             # carico in $t3 il valore memorizzato in reset_contatore
    lb $t4, SECONDI_RESET               # carico in $t4 il numero di secondi da raggiungere affinché avvenga il reset (5)
    blt $t3, $t4, fine_logica_temporale # limite non raggiunto, non resetto nulla ed esco dalla procedura

    # reset di TUTTO il sistema
    li $v0, 4                           # imposto la scrittura di una stringa
    la $a0, msg_reset_sistema           # carico l'indirizzo del messaggio di testo
    syscall                             # stampa
    sb $zero, COMMAND                   # azzero l'area di memoria COMMAND
    sh $zero, temp_contatore            # azzero il temp_contatore
    sb $zero, reset_contatore           # azzero il reset_contatore

fine_logica_temporale:
    jr $ra                              # ritorno al chiamante



# -------------------------------------------
# Subroutine: delay_1s
# Simula 1 secondo per un processore da 100 MHz.
#
# Il valore di DELAY_COUNT è stato calibrato per approssimare un secondo di attesa sul simulatore QtSPIM.
#
# CALCOLO TEORICO per un processore MIPS a 100 MHz con architettura multiciclo:
#   - Cicli di clock al secondo = 100.000.000
#   - Il loop di ritardo è composto da due istruzioni: 'addi' e 'bne'.
#   - In un'implementazione multi-ciclo, le istruzioni richiedono un numero variabile
#     di cicli (3-5). Ad esempio:
#       - 'addi' (formato I): 4 cicli di clock
#       - 'bne' (formato I): 3 cicli di clock
#   - Cicli totali per un'iterazione del loop = 4 + 3 = 7 cicli di clock.
#
#   - Iterazioni teoriche = (cicli totali) / (cicli per iterazione)
#                       = 100.000.000 / 7 = circa 14.285.714
#
# Il valore pratico di 10.000.000 è stato scelto per adattarsi all'overhead
# specifico del simulatore QtSPIM, che non emula l'hardware a questo livello di dettaglio.
# Potrebbe però non risultare così ben calibrato eseguendo il programma su altre macchine.
#
# Nota: nel calcolo dei cicli non sono state considerate le istruzioni lw $t0, DELAY_COUNT e jr $ra (fuori
# dal ciclo), dato che il loro contributo è ampiamente trascurabile rispetto alle milioni di iterazioni del ciclo.
# -------------------------------------------
delay_1s:

    lw $t0, DELAY_COUNT             # carico in $t0 il numero di iterazioni da effettuare
delay_loop:
    addi $t0, $t0, -1               # decremento di 1 il contatore delle iterazioni
    bne $t0, $zero, delay_loop      # esco dal ciclo terminate le iterazioni da compiere

    jr $ra                          # ritorno al chiamante



# ----------------------------------------------
# Subroutine: richiedi_numero_sensori
#  - Richiede all'utente il numero di sensori che
#    vuole utilizzare all'interno del sistema (1-16).
#  - Ripropone la richiesta fino a che l'utente
#    non inserisce un valore numerico accettabile.
# ----------------------------------------------
richiedi_numero_sensori:
    li $v0, 4                               # imposto la scrittura di una stringa 
    la $a0, msg_inserisci_sensori           # carico l'indirizzo del messaggio di testo
    syscall                                 # stampa

    li $v0, 5                               # imposto la lettura di un intero
    syscall                                 # attendo l'input dell'utente

    move $t0, $v0                           # memorizzo in $t0 l'input dell'utente
    lb $t1, MIN_SENSORI                     # carico in $t1 il valore minimo di sensori
    lb $t2, MAX_SENSORI                     # carico in $t2 il valore massimo di sensori
    blt $t0, $t1, errore_input_sensori      # se il numero inserito è minore del minimo, salto alla label di errore
    bgt $t0, $t2, errore_input_sensori      # se il numero inserito è maggiore del massimo, salto alla label di errore

    sb $t0, NUM_SENSORI_ATTIVI              # memorizzo il valore valido inserito nell'apposita posizione di memoria
    jr $ra                                  # fine della procedura

errore_input_sensori:
    li $v0, 4                               # imposto la scrittura di una stringa 
    la $a0, msg_errore_inserimento_sensori  # carico l'indirizzo del messaggio di errore
    syscall                                 # stampa
    j richiedi_numero_sensori               # ripropongo la richiesta



# -------------------------------------------
# Subroutine: scegli_modalita_simulazione
# - Chiede all'utente di scegliere la modalità di simulazione
#   (0 per manuale, 1 per automatica) e salva la scelta
#   nella variabile "modalita_simulazione".
# - Continua a chiedere finché l'input non è valido.
# -------------------------------------------
scegli_modalita_simulazione:
    li $v0, 4                       # imposto la scrittura di una stringa
    la $a0, msg_scegli_modalita     # carico l'indirizzo del messaggio di testo
    syscall                         # stampa

    li $v0, 5                       # imposto la lettura di un intero
    syscall                         # attendo l'input dell'utente
    move $t0, $v0                   # memorizzo in $t0 l'input dell'utente

    blt $t0, $zero, errore_modalita # se input < 0, errore
    li $t1, 1
    bgt $t0, $t1, errore_modalita   # se input > 1, errore

    # caso input valido (0 o 1)
    sb $t0, modalita_simulazione    # salvo la scelta
    jr $ra                          # ritorno al chiamante

errore_modalita:                    # errore nella scelta della modalità
    li $v0, 4                       # imposto la scrittura di una stringa
    la $a0, msg_errore_modalita     # carico l'indirizzo del messaggio di errore
    syscall                         # stampa
    j scegli_modalita_simulazione   # ripropongo la scelta



# -------------------------------------------
# Subroutine: gestisci_simulazione
# - Subroutine principale per gestire la simulazione del sistema.
# - Controlla la variabile "modalita_simulazione" e invoca la
#   subroutine corretta ("simulazione_automatica" o "simulazione_manuale"),
#   per aggiornare lo stato delle aree di memoria ALLARMS e TEMPERATURE.
# - Viene chiamata ad ogni ciclo del main_loop.
# -------------------------------------------
gestisci_simulazione:

    addi $sp, $sp, -4               # alloco 4 byte nello stack
    sw $ra, 0($sp)                  # salvo nello stack l'indirizzo di ritorno (necessario in una procedura annidata)
    lb $t0, modalita_simulazione    # carico in $t0 il valore indicante la modalità di simulazione
    bne $t0, $zero, exec_sim_auto   # se modalita != 0, salto a simulazione automatica

    jal simulazione_manuale         # altrimenti, eseguo la simulazione manuale
    j fine_gestisci_sim             # salto a fine_gestisci_sim

exec_sim_auto:
    jal simulazione_automatica      # eseguo la simulazione automatica

fine_gestisci_sim:
    lw $ra, 0($sp)                  # ripristino il valore iniziale di $ra
    addi $sp, $sp, 4                # ripristino il valore dello stack pointer
    jr $ra                          # ritorno al chiamante



# -------------------------------------------
# Subroutine: simulazione_automatica
# - Legge le temperature dalla tabella e popola TEMPERATURE.
# - Calcola dinamicamente lo stato in ALLARMS a partire dalle temperature lette
#   e dai valori di fumo pre-impostati nella tabella.
# - Quando completa la tabella, ricomincia dall'inizio (lettura circolare).
# -------------------------------------------
simulazione_automatica:

    # calcolo l'indirizzo della riga corrente nella tabella
    lb $t0, indice_tabella_sim                  # carico in $t0 l'indice corrente della tabella
    li $t1, 36                                  # carico in $t1 il valore 36 (byte di memoria per ogni riga della tabella)
    mul $t2, $t0, $t1                           # $t2 = i * 36, offset della riga corrente nella tabella
    la $t3, tabella_simulazione                 # carico in $t3 l'indirizzo base della tabella
    add $t3, $t3, $t2                           # $t3 = base + offset = indirizzo riga corrente

    # leggo il valore di ALLARMS dalla tabella, che sarà usato SOLO per i bit di FUMO (i bit di temperatura verranno sovrascritti e poi ricalcolati)
    lw $s1, 0($t3)                              # $s1 = valore di ALLARMS dalla tabella
    
    # inizializzo puntatori e contatori
    la $s4, TEMPERATURE                         # $s4 = puntatore a TEMPERATURE
    add $t3, $t3, 4                             # sposta il puntatore della riga oltre ALLARMS (spiazzamento di 1 word = 4 byte)
    li $s3, 0                                   # $s3 = contatore sensore corrente (i)
    lb $t9, NUM_SENSORI_ATTIVI                  # carico in $t9 il numero di sensori attivi

copia_e_crea_loop:                              # copio i valori della tabella in memoria e creo il loop
    beq $s3, $t9, fine_auto_loop                # esco dal loop terminati i sensori

    # copio i dati in TEMPERATURE
    sh $s3, 0($s4)                              # salvo l'ID del sensore (primi 2 byte)
    lh $t4, 0($t3)                              # leggo la temperatura dalla tabella
    sh $t4, 2($s4)                              # salvo la temperatura in memoria (secondi 2 byte)

    # calcola il bit di stato della temperatura
    lb $t5, SOGLIA_TEMPERATURA_ESTINZIONE       # carico in $t5 la soglia di temperatura per l'estinzione (60)
    sgt $t1, $t4, $t5                           # $t1 = 1 se T > 60, altrimenti 0

    # aggiorno la word di ALLARMS ($s1)
    mul $t8, $s3, 2                             # calcolo lo scorrimento necessario per portare i bit del sensore corrente a destra ($t8 = i * 2, dove 2 è il numero di bit per sensore)
    li $t6, 0x1                                 # maschera per il bit di temperatura (0b01)
    sllv $t6, $t6, $t8                          # sposto la maschera nella posizione dei due bit del sensore corrente
    not $t6, $t6                                # inverto la maschera per azzerare il bit
    and $s1, $s1, $t6                           # azzero il bit di temperatura corrente 
    sllv $t1, $t1, $t8                          # sposto la maschera del nuovo stato di temperatura ($t1) nella posizione dei due bit del sensore corrente
    or $s1, $s1, $t1                            # imposto il bit di temperatura se necessario

    # aggiorno puntatori e contatore
    add $t3, $t3, 2                             # passo al prossimo valore di temperatura da leggere (dopo 2 byte)
    add $s4, $s4, 4                             # passo al prossimo valore di temperatura in memoria (dopo 4 byte)
    add $s3, $s3, 1                             # incremento di 1 il contatore del sensore corrente (i)
    j copia_e_crea_loop                         # riprendo il loop

fine_auto_loop:                                 # fine del loop
    sw $s1, ALLARMS                             # scrivo il valore finale e corretto in ALLARMS

    # aggiorno l'indice della tabella per il prossimo ciclo (logica circolare)
    lb $t0, indice_tabella_sim                  # carico in $t0 l'indice della riga corrente
    add $t0, $t0, 1                             # incremento l'indice di 1
    lb $t1, dimensione_tabella_sim              # carico in $t1 la dimensione della tabella
    bne $t0, $t1, indice_aggiornato             # se $t0 != $t1 (righe non ancora finite), lo mantengo
    li $t0, 0                                   # se se $t0 == $t1 (tabella completata), lo riazzero

indice_aggiornato:
    sb $t0, indice_tabella_sim                  # imposto l'indice della riga corrente al valore di $t0       
    jr $ra                                      # ritorno al chiamante



# -------------------------------------------
# Subroutine: simulazione_manuale
# Interagisce con l'utente per popolare manualmente i valori
# di ALLARMS e TEMPERATURE per ogni sensore attivo.
# -------------------------------------------
simulazione_manuale:
    # stampo il messaggio di avvio della simulazione manuale
    li $v0, 4
    la $a0, msg_sim_manuale_start
    syscall

    # inizializzo i registri per il loop
    li $s1, 0                               # $s1 = contenitore del valore finale di ALLARMS, inizializzato a 0
    lb $s2, NUM_SENSORI_ATTIVI              # $s2 = numero di sensori attivi
    li $s3, 0                               # $s3 = contatore del sensore corrente (i)
    la $s4, TEMPERATURE                     # $s4 = puntatore all'indirizzo base dell'area di memoria TEMPERATURE

manual_loop:
    # controllo la condizione di terminazione del loop
    beq $s3, $s2, fine_manual_loop          # se i == numero di sensori, esco dal loop

    # stampo l'intestazione per il sensore corrente: "Sensore [i]"
    li $v0, 4
    la $a0, msg_sim_sensore_n
    syscall                                 # stampa del messaggio
    li $v0, 1
    move $a0, $s3
    syscall                                 # stampa dell'indice

    # richiedo all'utente di inserire lo stato del FUMO (0 o 1)
    li $v0, 4
    la $a0, msg_sim_fumo                    # stampa del messaggio
    syscall
    li $v0, 5                               # leggo un intero
    syscall
    nop                                     # nop (istruzione a vuoto) di sicurezza per evitare errori di lettura
    move $t0, $v0                           # $t0 = valore inserito per lo stato del fumo

    # stampo nuovamente l'intestazione per il sensore corrente: "Sensore [i]"
    li $v0, 4
    la $a0, msg_sim_sensore_n
    syscall                                 # stampa del messaggio
    li $v0, 1
    move $a0, $s3
    syscall                                 # stampa dell'indice       

    # richiedo all'utente di inserire il valore esatto della TEMPERATURA
    li $v0, 4
    la $a0, msg_sim_temp_valore
    syscall                                 # stampa del messaggio
    li $v0, 5                               # leggo un intero
    syscall
    nop                                     # nop (istruzione a vuoto) di sicurezza per evitare errori di lettura
    move $t4, $v0                           # $t4 = valore inserito per la temperatura
    
    # calcola il bit di allarme per la temperatura
    lb $t5, SOGLIA_TEMPERATURA_ESTINZIONE   # carico in $t5 la soglia di temperatura
    sgt $t1, $t4, $t5                       # $t1 = 1 se temperatura > soglia, altrimenti 0

    # combina i bit di stato (fumo e temperatura) in una coppia di bit
    sll $t0, $t0, 1                         # sposta a sinistra di 1 il bit di fumo ($t0) per portarlo in posizione bit 1
    or $t2, $t0, $t1                        # $t2 = (bit_fumo << 1) | bit_temperatura: ora $t2 contiene lo stato a 2 bit del sensore

    # posiziono la coppia di bit di stato nella word finale di ALLARMS
    mul $t3, $s3, 2                         # calcola lo scorrimento necessario: $t3 = i * 2
    sllv $t2, $t2, $t3                      # sposta i 2 bit di stato ($t2) nella posizione corretta per il sensore i
    or $s1, $s1, $t2                        # aggiorna la word finale di ALLARMS ($s1) con i bit del sensore corrente

    # salvo ID e temperatura nell'area di memoria TEMPERATURE
    sh $s3, 0($s4)                          # salvo l'ID del sensore (i) nei primi 2 byte della struttura dati del sensore
    sh $t4, 2($s4)                          # salvo il valore della temperatura nei 2 byte successivi
    add $s4, $s4, 4                         # avanzo il puntatore di TEMPERATURE di 4 byte al prossimo sensore

    add $s3, $s3, 1                         # incremento il contatore del sensore
    j manual_loop                           # riprendo il loop

fine_manual_loop:
    sw $s1, ALLARMS                         # scrive il valore di $s1 nella zona di memoria ALLARMS
    jr $ra                                  # ritorno al chiamante



# -------------------------------------------
# Subroutine: stampa_stato
# Stampa a console un resoconto completo dello stato attuale del sistema,
# includendo i valori di memoria, i contatori e i messaggi di allarme
# corrispondenti allo stato del byte COMMAND.
# -------------------------------------------
stampa_stato:
    # alloco 16 byte sullo stack e salvo i registri da preservare
    addi $sp, $sp, -16 
    sw $s0, 0($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)

    # stampa dell'header del report di stato
    li $v0, 4
    la $a0, msg_stato_header
    syscall

    # sezione 1: stampa dettagliata di ogni sensore
    li $v0, 4
    la $a0, msg_dettaglio_sensori
    syscall

    # inizializzazione dei registri per il loop di stampa
    lw $s0, ALLARMS                         # $s0 = carico il valore completo della word ALLARMS
    la $s1, TEMPERATURE                     # $s1 = puntatore all'indirizzo base di TEMPERATURE
    lb $s2, NUM_SENSORI_ATTIVI              # $s2 = numero di sensori attivi
    li $s3, 0                               # $s3 = contatore del sensore corrente (i)

print_sensor_loop:
    beq $s3, $s2, end_print_sensor_loop     # se i == numero sensori, esco dal loop

    # stampa "Sensore: [i]"
    li $v0, 4
    la $a0, msg_sensore_id_header           # stampa del testo
    syscall
    li $v0, 1
    move $a0, $s3
    syscall                                 # stampa dell'indice

    # estraggo e stampo lo stato del fumo per il sensore corrente
    mul $t0, $s3, 2                         # calcolo lo scorrimento: $t0 = i * 2
    srlv $t1, $s0, $t0                      # sposto i 2 bit di stato del sensore corrente all'estrema destra
    andi $t1, $t1, 0x2                      # isolo il bit di fumo (maschera 0b10)
    
    li $v0, 4
    la $a0, msg_fumo_stato                  # stampa dell'etichetta "Fumo: "
    syscall

    beq $t1, $zero, print_fumo_no           # se il bit di fumo è 0, salta
    la $a0, msg_stato_si                    # altrimenti, preparo la stringa "Sì"
    j print_fumo_next

print_fumo_no:
    la $a0, msg_stato_no                    # preparo la stringa "No"

print_fumo_next:
    syscall                                 # stampa di "Sì" o "No"

    # estraggo e stampo la TEMPERATURA per il sensore corrente
    li $v0, 4
    la $a0, msg_temp_stato                  # stampa dell'etichetta "Temperatura: "
    syscall
    
    lh $a0, 2($s1)                          # leggo il valore della temperatura
    li $v0, 1
    syscall                                 # stampa del valore numerico
    
    li $v0, 4
    la $a0, msg_gradi_celsius               # stampa del testo " C"
    syscall
    
    li $v0, 4                               # stampa di un carattere di nuova riga per formattazione
    la $a0, new_line
    syscall

    # avanzo al prossimo sensore
    addi $s1, $s1, 4                        # avanzo il puntatore di TEMPERATURE di 4 byte
    addi $s3, $s3, 1                        # incrementa il contatore del sensore
    j print_sensor_loop                     # riprendo il loop

end_print_sensor_loop:
    # sezione 2: stampa contatori di sistema
    li $v0, 4
    la $a0, msg_stato_contatori             # stampa dell'intestazione per i contatori
    syscall
    li $v0, 1
    lh $a0, temp_contatore                  # carico e stampo il valore del contatore di temperatura
    syscall
    
    li $v0, 4
    la $a0, msg_contatore_secondi           # stampa dell'etichetta per il secondo contatore
    syscall
    li $v0, 1
    lb $a0, reset_contatore                 # carico e stampo il valore del contatore di reset
    syscall
    
    li $v0, 4
    la $a0, msg_secondi                     # stampa del testo " secondi"
    syscall

    # sezione 3: stampa dei messaggi di allarme basati sul byte COMMAND
    li $v0, 4                               # stampa di un carattere di nuova riga
    la $a0, new_line
    syscall

    lb $t1, COMMAND                         # carico il valore del byte COMMAND in $t1
    
    andi $t2, $t1, 0x1                      # controlla il bit 0 (sirena)
    beq $t2, $zero, skip_print_sirena       # se è 0, salto la stampa
    li $v0, 4; la $a0, msg_sirena           # altrimenti, stampo il messaggio di allarme sirena
    syscall

skip_print_sirena:
    andi $t2, $t1, 0x2                      # controllo il bit 1 (impianto di estinzione ad acqua)
    beq $t2, $zero, skip_print_acqua        # se è 0, salto la stampa
    li $v0, 4; la $a0, msg_acqua            # altrimenti, stampo il messaggio di allarme acqua
    syscall
    
skip_print_acqua:
    andi $t2, $t1, 0x4                      # controllo il bit 2 (chiamata VVFF)
    beq $t2, $zero, skip_print_vvff         # se è 0, salto la stampa
    li $v0, 4; la $a0, msg_vvff             # altrimenti, stampo il messaggio di allarme VVFF
    syscall

skip_print_vvff:
    # sezione 4: stampa contenuto dell'area di memoria RECORD
    li $v0, 4
    la $a0, msg_stato_record_header         # stampo l'intestazione per la sezione RECORD
    syscall

    lb $t0, record_count                    # carico il numero di ID salvati in RECORD
    beq $t0, $zero, print_no_record         # se è 0, non ci sono record da stampare
    
    la $t1, RECORD                          # $t1 = puntatore all'inizio di RECORD
    li $t2, 0                               # $t2 = contatore per il loop di stampa

print_record_loop:
    beq $t2, $t0, end_print_record          # se il contatore raggiunge il numero di record, esco
    li $v0, 4; la $a0, msg_stato_sensore_id # stampa del testo "ID sensore in allarme: "
    syscall
    li $v0, 1
    lh $a0, 0($t1)                          # carica e stampo l'ID del sensore
    syscall
    addi $t1, $t1, 2                        # avanzo al prossimo ID (2 byte)
    addi $t2, $t2, 1                        # incremento il contatore del loop
    j print_record_loop                     # riprendo il ciclo

print_no_record:
    li $v0, 4; la $a0, msg_stato_no_record  # stampo che non ci sono record
    syscall

end_print_record:
   
    li $v0, 4
    la $a0, msg_stato_footer                # stampo il footer del report
    syscall
    
    # ripristino i registri salvati
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    lw $s2, 8($sp)
    lw $s3, 12($sp)
    addi $sp, $sp, 16                       # riprstino il valore dello stack pointer
    jr $ra                                  # ritorno al chiamante



# -------------------------------------------
# EXCEPTION HANDLER
# -------------------------------------------
# Ho scelto di implementare un gestore delle eccezioni per
# intercettare errori non recuperabili (es. overflow, errori di indirizzamento).
# Ho preferito non garantire un ripristino del sistema, siccome non sarebbe
# sempre possibile farlo in sicurezza (appunto in caso di eccezioni non recuperabili).
# La soluzione consiste nel mettere il sistema in uno stato di "allerta guasto",
# segnalando l'anomalia tramite un apposito messaggio di errore.
# L'esecuzione del programma viene terminata in un loop infinito, che preserva
# lo stato del programma in attesa di un intervento di manutenzione esterno.
# -------------------------------------------

.ktext 0x80000180                   # indirizzo standard per il gestore di eccezioni in kernel mode
exception_handler:

    addi $sp, $sp, -4               # alloco 4 byte nello stack
    sw   $v0, 0($sp)                # salvo il valore di $v0 nello stack per preservarne il valore in caso di ripristino

    mfc0 $k0, $13                   # copio il registro "Cause" in $k0 per riportare la causa dell'eccezione
    mfc0 $k1, $14                   # copio il registro "EPC" in $k1, che contiene l'indirizzo dell'istruzione dove è avvenuta l'eccezione

    sgt  $v0, $k0, 0x44             # distinguo le eccezioni dagli interrupt, verificano se $k0 (Cause) sia maggiore di 0x44
    bnez $v0, exit_handler          # se il risultato è 1 (interrupt), lo ignoro e esco dal gestore

    # eccezione rilevata: considero qualsiasi eccezione non filtrata come fatale
    
    # preparo gli argomenti per la subroutine di gestione dell'errore
    andi $a0, $k0, 0x7C             # isola il campo ExcCode (bit 2-6) dal registro Cause
    srl  $a0, $a0, 2                # sposto a destra di 2 (per ottenere il valore numerico del codice di eccezione) e lo passo come primo argomento ($a0)
    move $a1, $k1                   # passo l'indirizzo dell'errore (EPC) come secondo argomento ($a1)
    
    jal  critical_fault_routine     # chiamo la subroutine specifica per gestire e segnalare l'eccezione

exit_handler:
    
    lw   $v0, 0($sp)                # ripristino il registro $v0
    addi $sp, $sp, 4                # ripristino il valore dello stack pointer
    eret                            # ritorno dall'eccezione ripristinando lo stato del processore

# gestione degli errori fatali
critical_fault_routine:

    move $s0, $a0                   # salvo ExcCode in $s0
    move $s1, $a1                   # salvo EPC in $s1

    # stampo un messaggio di errore per avvisare l'utente
    li   $v0, 4
    la   $a0, msg_errore_critico
    syscall
    
    # stampo il codice numerico dell'eccezione per l'analisi del problema
    li   $v0, 4
    la   $a0, msg_errore_code
    syscall
    li   $v0, 1
    move $a0, $s0                   # uso il valore di ExcCode salvato in $s0
    syscall
    
    # stampo l'indirizzo dell'istruzione che ha causato l'errore
    li   $v0, 4
    la   $a0, msg_errore_epc
    syscall
    li   $v0, 1                     # stampo l'indirizzo come intero in base 10
    move $a0, $s1                   # uso il valore di EPC salvato in $s1
    syscall


safe_halt:
    j    safe_halt                  # LOOP INFINITO: blocca il sistema in uno stato di guasto controllato.
                                    # In un sistema reale, questo impedisce un comportamento indefinito e
                                    # attende un reset manuale, preservando lo stato dei registri e della
                                    # memoria per la successiva analisi del guasto.
