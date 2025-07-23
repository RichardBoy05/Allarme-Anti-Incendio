[![ita](https://img.shields.io/badge/lang-ita-green.svg)](README.md)
[![en](https://img.shields.io/badge/lang-en-red.svg)](README-ENG.md)

# Progetto MIPS: Allarme Anti-Incendio

**Autore:** Richard Meoli  
**Corso:** "Calcolatori Elettronici", Università degli Studi di Bergamo  
**Anno accademico:** 2024/25

---

## Flowchart

In questa sezione vengono presentati i diagrammi di flusso (flowchart) che illustrano la logica operativa delle subroutine principali del sistema.

**Legenda dei simboli:**
*   **Ovale (Verde/Rosso):** inizio / fine della subroutine.
*   **Rettangolo (Blu):** operazione o processo interno.
*   **Diamante (Arancione):** biforcazione del flusso (decisione).
*   **Rettangolo con doppia barra (Viola):** chiamata ad una subroutine.
*   **Parallelogramma (Azzurro):** operazioni di input/output.
*   **Cerchio (Grigio):** connettore di flusso (tipicamente una `label` nel codice).

### Subroutine incluse nei flowchart:
*   `main`: diagramma generale che descrive il ciclo di vita del programma, gestendo le chiamate a tutte le altre funzioni in un loop continuo.
*   `analizza_ALLARMS`: si occupa di leggere la parola di stato ALLARMS e di estrarre, per ogni sensore, le informazioni relative alla presenza di fumo e temperatura critica.
*   `aggiorna_COMMAND`: contiene la logica centrale per l'attivazione degli allarmi (sirena, acqua, VVFF) in base agli stati rilevati e ai timer di sistema.
*   `analizza_TEMPERATURE`: itera sull'area di memoria TEMPERATURE per determinare se le condizioni per il reset siano soddisfatte e per registrare gli ID dei sensori con temperatura eccessiva.
*   `gestisci_contatori_temporali`: implementa la logica temporale del sistema, gestendo i contatori per l'attivazione dell'impianto di estinzione e per il reset generale.

### Subroutine escluse dai flowchart:
Si è invece scelto di non realizzare i flowchart per le seguenti subroutine, caratterizzate dall'essere particolarmente ripetitive e/o lineari o dal riguardare esclusivamente la fase di simulazione.
*   `richiedi_numero_sensori` / `scegli_modalita_simulazione`: funzioni di I/O che gestiscono l'interazione iniziale con l'utente; la loro logica è una semplice sequenza di "stampa messaggio -> leggi input -> validazione input".
*   `gestisci_simulazione` / `simulazione_automatica` / `simulazione_manuale`: si occupano di popolare le aree di memoria ALLARMS e TEMPERATURE con dati di test. La loro logica è un ciclo ripetitivo di lettura/scrittura dati.
*   `stampa_stato`: subroutine di utility che si limita a leggere valori dalla memoria e a stamparli a schermo in modo formattato. Il suo flusso è una lunga sequenza lineare di operazioni di stampa.
*   `delay_1s`: subroutine di attesa la cui logica consiste in un semplice ciclo di decremento di un contatore.
*   `exception_handler`: gestore delle eccezioni, caratterizzato da un flusso logico molto semplice (leggi registri -> ignora interrupts -> stampa -> loop infinito).

---

### main
![Flowchart della subroutine main](./flowcharts/main.png)

### analizza_ALLARMS
![Flowchart della subroutine analizza_ALLARMS](./flowcharts/analizza_ALLARMS.png)

### aggiorna_COMMAND
![Flowchart della subroutine aggiorna_COMMAND](./flowcharts/aggiorna_COMMAND.png)

### analizza_TEMPERATURE
![Flowchart della subroutine analizza_TEMPERATURE](./flowcharts/analizza_TEMPERATURE.png)

### gestisci_contatori_temporali
![Flowchart della subroutine gestisci_contatori_temporali](./flowcharts/gestisci_contatori_temporali.png)

---

## SNIPPET di codice più rilevanti

### 1) Calibrazione del delay tramite calcolo dei cicli di clock

Per sospendere l'esecuzione del programma per circa un secondo è stato implementato un ciclo di attesa attivo (*busy-waiting*). La durata di questo ciclo è determinata da una costante preimpostata, `DELAY_COUNT`.

Il valore di tale costante è stato derivato da un'analisi teorica del tempo di esecuzione, basata sulle specifiche fornite del processore, e successivamente calibrato empiricamente per adattarsi alle performance del simulatore QtSPIM.

```asm
delay_1s:
    lw $t0, DELAY_COUNT             # carico in $t0 il numero di iterazioni da effettuare
delay_loop:
    addi $t0, $t0, -1               # decremento di 1 il contatore delle iterazioni
    bne $t0, $zero, delay_loop      # esco dal ciclo terminate le iterazioni da compiere
    jr $ra                          # ritorno al chiamante
```

**Analisi teorica e calibrazione**

Il calcolo teorico si basa sui seguenti parametri:
*   **Frequenza del processore:** 100 MHz (ovvero 100.000.000 cicli di clock al secondo).
*   **Composizione del loop:** il ciclo di ritardo è costituito da due istruzioni: `addi` e `bne`.
*   **Costo delle istruzioni (architettura multiciclo):** `addi` richiede 4 cicli di clock, `bne` invece 3.
*   **Costo totale per iterazione:** 4 + 3 = 7 cicli di clock.

Sulla base di questi dati, il numero di iterazioni teoriche eseguibili in un secondo è: 100.000.000 cicli / 7 cicli per iterazione = circa 14.285.714 iterazioni.

Nonostante il risultato teorico, il valore pratico per `DELAY_COUNT` è stato impostato a 10.000.000. Tale scostamento è necessario per compensare l'overhead intrinseco del QtSPIM, il quale non emula il timing a livello di ciclo di clock con assoluta fedeltà. Di conseguenza, questo valore calibrato è specifico per l'ambiente di test e potrebbe richiedere un'ulteriore ricalibrazione su altri simulatori o su hardware reale.

Si noti infine che le istruzioni di setup del ciclo (`lw` e `jr`), essendo esterne al loop, sono state escluse dal calcolo, poiché il loro impatto sul tempo di esecuzione totale è trascurabile rispetto ai milioni di iterazioni eseguite.

### 2) Analisi dei i 2 bit di stato per ciascuno dei 16 sensori

Per isolare i dati di un sensore specifico i, è necessario calcolare uno "spostamento" (shift) dinamico. Moltiplicando l'indice del sensore i per 2 (numero di bit per sensore) si ottiene il numero di posizioni di cui la parola `ALLARMS` deve essere fatta scorrere a destra: ricorro poi all'istruzione `srlv`, poiché l'entità dello shift non è una costante ma dipende dal valore del registro $t2. Infine, un'operazione di AND con una maschera (0x3, ovvero 0b11) isola i due bit di interesse.

```asm
# calcolo lo scorrimento necessario per portare i bit del sensore corrente a destra
mul $t2, $t1, 2         # $t2 = i * 2 (dove 2 è il numero di bit per sensore)

# estraggo i 2 bit di stato del sensore corrente
srlv $t3, $t0, $t2      # scorro l'intera parola ALLARMS a destra di i * 2 posizioni
andi $t3, $t3, 0x3      # isolo i 2 bit di interesse con una maschera (0b11)

# ora $t3 contiene il valore di stato (da 0 a 3 in base 10)
```

### 3) Exception handler

Si è implementato un gestore di eccezioni che intercetta qualsiasi trap del processore. Viene eseguito in modalità kernel, salva i registri di stato `Cause` (che contiene il codice dell'errore) ed `EPC` (l'indirizzo dell'istruzione che ha fallito), stampa un messaggio di diagnostica per l'operatore e blocca il sistema in un loop infinito (`safe_halt`) per prevenire ulteriori danni. Nota: per testare il suo funzionamento è sufficiente "decommentare" una delle due istruzioni posizionate nell'apposito blocco di test (situato nel main, che testa nello specifico l'overflow aritmetico e un errore di indirizzamento).

```asm
mfc0 $k0, $13           # copio il registro "Cause" in $k0 per riportare la causa dell'eccezione
mfc0 $k1, $14           # copio il registro "EPC" in $k1, che contiene l'indirizzo dell'istruzione dove è avvenuta l'eccezione

sgt  $v0, $k0, 0x44     # distinguo le eccezioni dagli interrupt, verificano se $k0 (Cause) sia maggiore di 0x44
bnez $v0, exit_handler  # se il risultato è 1 (interrupt), lo ignoro e esco dal gestore

# eccezione rilevata: considero qualsiasi eccezione non filtrata come fatale
# preparo gli argomenti per la subroutine di gestione dell'errore
andi $a0, $k0, 0x7C     # isola il campo ExcCode (bit 2-6) dal registro Cause
srl  $a0, $a0, 2        # sposto a destra di 2 (per ottenere il valore numerico del codice di eccezione) e lo passo come primo argomento
move $a1, $k1           # passo l'indirizzo dell'errore (EPC) come secondo argomento ($a1)
```

Le pseudo-istruzioni `sgt` e `bnez` sono state utilizzate per ignorare le interrupts, in modo da intercettare solamente le eccezioni (trap).

```asm
safe_halt:
    j    safe_halt
```

Si è deciso di porre il sistema in uno stato di loop infinito in caso di eccezione, al fine di poterlo "bloccare" in uno stato controllato di guasto. In un sistema reale, questo impedisce un comportamento indefinito e attende un reset manuale esterno, preservando lo stato dei registri e della memoria per la successiva analisi del problema.

### 4) Disattivazione della chiamata ai VVFF

```asm
vvff_check_timer:
    # condizione di chiamata NON verificata: controllo se la chiamata era già attiva e in tal caso la disattivo
    lb $t4, vvf_timer               # carico in $t4 il valore del timer
    beq $t4, $zero, fine_vvff_check # se timer già a 0 non c'era alcuna chiamata in corso, per cui esco

    # caso timer > 0
    addi $t4, $t4, -1               # decremento il timer di un secondo
    sb $t4, vvf_timer               # aggiorno il suo valore in memoria
    
    # se il timer è appena arrivato a 0, il bit VVFF deve essere spento;
    # altrimenti, la chiamata deve rimanere attiva per questo ciclo
    bne $t4, $zero, fine_vvff_check
    
    # timer è appena arrivato a 0, spengo il bit
    not $t5, $t5                    # inverto la maschera (da 00000100 a 11111011)
    and $t0, $t0, $t5               # uso un AND per azzerare solo il bit dei VVFF

fine_vvff_check:
```

La chiamata ai VVFF deve essere attivata istantaneamente in condizioni di massima criticità (fumo e temperatura eccessiva nello stesso sensore), ma deve disattivarsi automaticamente dopo 1 secondo, indipendentemente dallo stato degli altri allarmi.

Per implementare questo comportamento ho utilizzato una variabile-timer dedicata (`vvf_timer`). Quando la condizione critica si verifica, il bit dei VVFF viene attivato e il timer impostato al valore desiderato (in questo caso, 1 secondo). Nei cicli successivi, se la condizione critica è cessata, il programma controlla questo timer: lo decrementa e, solo quando raggiunge lo zero, procede alla disattivazione del bit specifico.

**Nota:** la logica è stata volutamente progettata per essere generica. Invece di limitarsi a disattivare l'allarme al ciclo successivo, il codice controlla esplicitamente che il timer abbia raggiunto lo zero. Questo rende il sistema flessibile: per modificare la durata dell'impulso della chiamata (ad esempio, portarla a 3 secondi), sarebbe sufficiente cambiare il valore caricato nel timer al momento dell'attivazione, senza dover alterare la logica di disattivazione.
